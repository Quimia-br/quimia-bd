"""
Quimia — Gerador de dados: incompatibilidade_regra

Esta tabela alimenta o fn_match_produtos: uma regra errada vira alerta falso
ou, pior, um "compatível" falso. Por isso as linhas VÁLIDAS não são mais
sorteadas — vêm de um seed curado manualmente
(sql/data_load/seeds/seed_incompatibilidade_regra.csv), em que cada regra
traz as duas classes, a severidade, a descrição do risco e a FONTE.

Regras com fonte ainda não conferida ficam no seed com ativo=false: entram
na tabela para revisão, mas o fn_match as ignora até alguém ativá-las.

Cada lado (A e B) da regra precisa ser EXATAMENTE substancia OU classe
(nunca os dois, nunca nenhum) — regra espelhada no CHECK da tabela oficial.
Cada lado do seed é uma classe (classe_a/classe_b) ou, se cas_a/cas_b estiver
preenchido, uma substância pelo CAS. Os IDs são resolvidos em runtime contra
o banco (IDENTITY pode variar entre cargas).

O gerador acrescenta, por cima do seed, só RUÍDO INVÁLIDO pro validate
(toda linha de ruído deve ser rejeitada; nenhuma regra aleatória entra):
  - lado A com os dois preenchidos (viola XOR)
  - lado B com nenhum preenchido (viola XOR)
  - severidade fora do CHECK
  - descricao_risco vazia
  - id de classe inexistente

Pré-requisito: rodar os pipelines de `substancia` e `classe_quimica`
antes deste.

Uso:
    python generate_incompatibilidade_regra.py
    python generate_incompatibilidade_regra.py --n-ruido 15 --saida incompatibilidade_regra.csv
"""

import argparse
import csv
import random
from pathlib import Path

from src.database.connection import get_connection

random.seed(42)

SEED_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "sql" / "data_load" / "seeds" / "seed_incompatibilidade_regra.csv"
)

SEVERIDADES_INVALIDAS = ["moderada", "extrema", "leve", ""]

TIPOS_RUIDO = [
    "lado_a_ambos",
    "lado_b_nenhum",
    "severidade_invalida",
    "descricao_vazia",
    "classe_inexistente",
]

CAMPOS = [
    "id_substancia_a", "id_classe_a",
    "id_substancia_b", "id_classe_b",
    "severidade", "descricao_risco", "fonte", "ativo",
]


def buscar_ids(conn, tabela):
    cur = conn.cursor()
    cur.execute(f"SELECT id FROM {tabela}")
    ids = [str(row[0]) for row in cur.fetchall()]
    cur.close()
    return ids


def buscar_classe_por_nome(conn):
    cur = conn.cursor()
    cur.execute("SELECT id, nome FROM classe_quimica")
    resultado = {nome: str(id_) for id_, nome in cur.fetchall()}
    cur.close()
    return resultado


def carregar_seed():
    if not SEED_PATH.exists():
        raise FileNotFoundError(
            f"Seed não encontrado em {SEED_PATH}. "
            "Crie o arquivo com as regras de incompatibilidade curadas."
        )
    with open(SEED_PATH, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def buscar_substancia_por_cas(conn):
    cur = conn.cursor()
    cur.execute("SELECT cas_numero, id FROM substancia WHERE cas_numero IS NOT NULL")
    resultado = {cas: str(id_) for cas, id_ in cur.fetchall()}
    cur.close()
    return resultado


def resolver_regras_curadas(conn):
    """
    Lê o seed e resolve cada lado contra os IDs reais do banco: cas_a/cas_b
    (substância) quando preenchido, senão classe_a/classe_b (classe). Pula,
    com aviso, regras cujo lado não existe no banco atual (ex: seed desatualizado).
    """
    mapa_classe = buscar_classe_por_nome(conn)
    mapa_cas = buscar_substancia_por_cas(conn)

    def resolver_lado(linha, lado):
        cas = (linha.get(f"cas_{lado}") or "").strip()
        if cas:
            return mapa_cas.get(cas), "", cas
        classe = linha[f"classe_{lado}"].strip()
        return None, mapa_classe.get(classe), classe

    regras = []
    for linha in carregar_seed():
        sub_a, cls_a, nome_a = resolver_lado(linha, "a")
        sub_b, cls_b, nome_b = resolver_lado(linha, "b")

        if not ((sub_a or cls_a) and (sub_b or cls_b)):
            print(
                f"[aviso] regra não resolvida no banco atual: "
                f"'{nome_a}' x '{nome_b}' — pulada"
            )
            continue

        regras.append({
            "id_substancia_a": sub_a or "",
            "id_classe_a": cls_a or "",
            "id_substancia_b": sub_b or "",
            "id_classe_b": cls_b or "",
            "severidade": linha["severidade"].strip(),
            "descricao_risco": linha["descricao_risco"].strip(),
            "fonte": linha["fonte"].strip(),
            "ativo": linha["ativo"].strip(),
        })

    return regras


def gerar_ruido(base, tipo, ids_substancia):
    """Copia uma regra curada e estraga exatamente um campo."""
    linha = dict(base)
    if tipo == "lado_a_ambos":
        linha["id_substancia_a"] = random.choice(ids_substancia)
        linha["id_classe_a"] = linha["id_classe_a"] or "1"
    elif tipo == "lado_b_nenhum":
        linha["id_classe_b"] = ""
        linha["id_substancia_b"] = ""
    elif tipo == "severidade_invalida":
        linha["severidade"] = random.choice(SEVERIDADES_INVALIDAS)
    elif tipo == "descricao_vazia":
        linha["descricao_risco"] = ""
    else:
        linha["id_classe_a"] = str(random.randint(900000, 999999))
    return linha


def gerar_incompatibilidade_regra(regras_curadas=None, ids_substancia=None, ids_classe=None, n_ruido=15):
    if not regras_curadas:
        raise ValueError(
            "Nenhuma regra curada resolvida a partir do seed. "
            "Confira o seed_incompatibilidade_regra.csv e se as classes existem no banco atual."
        )
    if not ids_substancia:
        raise ValueError(
            "Nenhuma substância encontrada na tabela oficial `substancia`. "
            "Rode o pipeline de substancia antes deste."
        )
    if not ids_classe:
        raise ValueError(
            "Nenhuma classe química encontrada na tabela oficial `classe_quimica`. "
            "Rode o pipeline de classe_quimica antes deste."
        )

    linhas = [dict(r) for r in regras_curadas]

    for i in range(n_ruido):
        base = random.choice(regras_curadas)
        linhas.append(gerar_ruido(base, TIPOS_RUIDO[i % len(TIPOS_RUIDO)], ids_substancia))

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-ruido", type=int, default=15, help="quantidade de linhas inválidas de ruído")
    parser.add_argument("--saida", default="incompatibilidade_regra.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    conn = get_connection()
    ids_substancia = buscar_ids(conn, "substancia")
    ids_classe = buscar_ids(conn, "classe_quimica")
    regras_curadas = resolver_regras_curadas(conn)
    conn.close()

    linhas = gerar_incompatibilidade_regra(
        regras_curadas=regras_curadas,
        ids_substancia=ids_substancia,
        ids_classe=ids_classe,
        n_ruido=args.n_ruido,
    )

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=CAMPOS)
        writer.writeheader()
        writer.writerows(linhas)

    print(
        f"{args.saida} gerado com {len(linhas)} linhas "
        f"({len(regras_curadas)} regras curadas + {len(linhas) - len(regras_curadas)} de ruído)"
    )
