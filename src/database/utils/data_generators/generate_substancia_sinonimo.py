"""
Quimia — Gerador de dados: substancia_sinonimo

Sinônimo errado faz o fn_processar_fds_raw_json resolver o ingrediente da FDS
para a substância errada (e o match decidir em cima disso). Por isso as linhas
VÁLIDAS não são mais variações sorteadas (ex: "Ácido c." servia a duas
substâncias, e o nome-fantasia saía de palavra aleatória) — vêm de um seed
curado manualmente (sql/data_load/seeds/seed_substancia_sinonimo.csv), com
nomes alternativos reais de cada substância, resolvidos por CAS (ou por
nome_canonico quando o CAS é nulo).

Nome FUNCIONAL genérico ("propelente", "tensoativo aniônico") não entra como
sinônimo: a identidade desses ingredientes é o CAS. Um sinônimo genérico
resolveria qualquer FDS com esse nome para a mesma substância, mesmo com
outro CAS.

`sinonimo_normalizado` é UNIQUE globalmente na tabela oficial (não
apenas por substância), então o gerador injeta de propósito, por cima do seed,
só RUÍDO INVÁLIDO (toda linha de ruído deve ser rejeitada):
  - sinônimo repetido (mesmo texto saindo 2x, pra testar a rejeição
    por duplicidade dentro do lote)
  - id_substancia inexistente (pra testar a rejeição por FK)
  - sinônimo vazio (pra testar campo obrigatório)

sinonimo_normalizado NÃO vai no CSV — é calculado no validate/migrate
(lower + remoção de acento + trim), igual já é feito com nome/marca.

Pré-requisito: rodar o pipeline de `substancia` antes deste.

Uso:
    python generate_substancia_sinonimo.py
    python generate_substancia_sinonimo.py --n-ruido 20 --saida substancia_sinonimo.csv
"""

import argparse
import csv
import random
from pathlib import Path

from src.database.connection import get_connection

random.seed(42)

SEED_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "sql" / "data_load" / "seeds" / "seed_substancia_sinonimo.csv"
)

TIPOS_RUIDO = ["repetido", "id_inexistente", "vazio"]


def buscar_substancias(conn):
    """Busca (id, nome_canonico) das substâncias já migradas."""
    cur = conn.cursor()
    cur.execute("SELECT id, nome_canonico FROM substancia")
    resultado = [(str(row[0]), row[1]) for row in cur.fetchall()]
    cur.close()
    return resultado


def buscar_substancia_por_cas_ou_nome(conn):
    """Retorna dict { (cas_numero ou None, nome_canonico) -> id }"""
    cur = conn.cursor()
    cur.execute("SELECT id, nome_canonico, cas_numero FROM substancia")
    resultado = {(cas, nome): str(id_) for id_, nome, cas in cur.fetchall()}
    cur.close()
    return resultado


def carregar_seed():
    if not SEED_PATH.exists():
        raise FileNotFoundError(
            f"Seed não encontrado em {SEED_PATH}. "
            "Crie o arquivo com os sinônimos curados por substância."
        )
    with open(SEED_PATH, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def resolver_sinonimos_curados(conn):
    """
    Lê o seed e resolve (cas/nome) -> id_substancia contra o banco atual.
    Pula, com aviso, linhas cuja substância não existe no banco.
    """
    mapa_substancia = buscar_substancia_por_cas_ou_nome(conn)

    curados = []
    for linha in carregar_seed():
        cas = linha["cas_numero"].strip() or None
        nome = linha["nome_canonico"].strip()
        id_substancia = mapa_substancia.get((cas, nome))

        if not id_substancia:
            print(
                f"[aviso] sinônimo não resolvido no banco atual: "
                f"substancia='{nome}' (cas={cas}) sinonimo='{linha['sinonimo']}' — pulado"
            )
            continue

        curados.append({"id_substancia": id_substancia, "sinonimo": linha["sinonimo"].strip()})

    return curados


def gerar_substancia_sinonimo(sinonimos_curados=None, substancias=None, n_ruido=20):
    if not substancias:
        raise ValueError(
            "Nenhuma substância encontrada na tabela oficial `substancia`. "
            "Rode o pipeline de substancia antes deste."
        )
    if not sinonimos_curados:
        raise ValueError(
            "Nenhum sinônimo curado resolvido a partir do seed. "
            "Confira o seed_substancia_sinonimo.csv e se os dados batem com o banco atual."
        )

    linhas = [dict(s) for s in sinonimos_curados]

    for i in range(n_ruido):
        tipo = TIPOS_RUIDO[i % len(TIPOS_RUIDO)]
        base = random.choice(sinonimos_curados)

        if tipo == "repetido":
            linhas.append(dict(base))
        elif tipo == "id_inexistente":
            linhas.append({"id_substancia": str(random.randint(900000, 999999)), "sinonimo": base["sinonimo"]})
        else:
            linhas.append({"id_substancia": base["id_substancia"], "sinonimo": ""})

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n-ruido", type=int, default=20, help="quantidade de linhas inválidas de ruído")
    parser.add_argument("--saida", default="substancia_sinonimo.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    conn = get_connection()
    substancias = buscar_substancias(conn)
    sinonimos_curados = resolver_sinonimos_curados(conn)
    conn.close()

    linhas = gerar_substancia_sinonimo(
        sinonimos_curados=sinonimos_curados, substancias=substancias, n_ruido=args.n_ruido
    )

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["id_substancia", "sinonimo"])
        writer.writeheader()
        writer.writerows(linhas)

    print(
        f"{args.saida} gerado com {len(linhas)} linhas "
        f"({len(sinonimos_curados)} sinônimos curados + {len(linhas) - len(sinonimos_curados)} de ruído)"
    )
