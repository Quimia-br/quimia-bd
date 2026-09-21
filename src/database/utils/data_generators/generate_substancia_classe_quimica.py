"""
Quimia — Gerador de dados: substancia_classe_quimica

Diferente de outras versoes do generate, este gerador NÃO sorteia pares
aleatórios de substancia x classe_quimica — isso gerava combinações
quimicamente absurdas (ex: Ácido fosfórico classificado como "base").

Consome um seed curado manualmente
(sql/data_load/seeds/seed_substancia_classe_quimica.csv), que mapeia
cada substância real (por CAS, com fallback por nome_canonico quando
o CAS é nulo, como em "Fragrância") às classes quimicamente corretas.

Os IDs de substancia/classe_quimica são resolvidos em runtime contra o
banco (não fixos no seed), porque IDENTITY pode variar entre cargas.

Ruído proposital pro validate é mantido, mas agora aplicado em CIMA
dos pares corretos (não substituindo a curadoria):
  - repete um par válido (testa UNIQUE)
  - injeta id inexistente dos dois lados
  - injeta id_classe_quimica vazio

Pré-requisito: rodar os pipelines de `substancia` e `classe_quimica`
antes deste, e o seed precisar existir em
sql/data_load/seeds/seed_substancia_classe_quimica.csv.

Uso:
    python generate_substancia_classe_quimica.py
    python generate_substancia_classe_quimica.py --n 60 --saida substancia_classe_quimica.csv
"""

import argparse
import csv
import random
from pathlib import Path

from src.database.connection import get_connection

random.seed(42)

SEED_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "sql" / "data_load" / "seeds" / "seed_substancia_classe_quimica.csv"
)


def buscar_ids(conn, tabela):
    cur = conn.cursor()
    cur.execute(f"SELECT id FROM {tabela}")
    ids = [str(row[0]) for row in cur.fetchall()]
    cur.close()
    return ids


def buscar_substancia_por_cas_ou_nome(conn):
    """Retorna dict { (cas_numero ou None, nome_canonico) -> id }"""
    cur = conn.cursor()
    cur.execute("SELECT id, nome_canonico, cas_numero FROM substancia")
    resultado = {}
    for id_, nome, cas in cur.fetchall():
        resultado[(cas, nome)] = str(id_)
    cur.close()
    return resultado


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
            "Crie o arquivo com o mapa curado substância -> classe química."
        )
    with open(SEED_PATH, newline="", encoding="utf-8-sig") as f:
        return list(csv.DictReader(f))


def resolver_pares_curados(conn):
    """
    Lê o seed e resolve (cas/nome, nome_classe) -> (id_substancia, id_classe_quimica)
    contra os IDs reais do banco. Pula silenciosamente pares cujo lado
    substância ou classe não exista no banco atual (ex: seed desatualizado).
    """
    seed = carregar_seed()
    mapa_substancia = buscar_substancia_por_cas_ou_nome(conn)
    mapa_classe = buscar_classe_por_nome(conn)

    pares_resolvidos = []
    for linha in seed:
        cas = linha["cas_numero"].strip() or None
        nome = linha["nome_canonico"].strip()
        nome_classe = linha["nome_classe"].strip()

        id_substancia = mapa_substancia.get((cas, nome))
        id_classe = mapa_classe.get(nome_classe)

        if id_substancia and id_classe:
            pares_resolvidos.append((id_substancia, id_classe))
        else:
            print(
                f"[aviso] seed não resolvido no banco atual: "
                f"substancia='{nome}' (cas={cas}) x classe='{nome_classe}' — pulado"
            )

    return pares_resolvidos


def gerar_substancia_classe_quimica(n=60, ids_substancia=None, ids_classe=None, pares_curados=None):
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
    if not pares_curados:
        raise ValueError(
            "Nenhum par curado resolvido a partir do seed. "
            "Confira o seed_substancia_classe_quimica.csv e se os dados batem com o banco atual."
        )

    linhas = []

    for id_substancia, id_classe in pares_curados:
        linhas.append({"id_substancia": id_substancia, "id_classe_quimica": id_classe})

    faltam = max(0, n - len(linhas))
    for _ in range(faltam):
        roll = random.random()

        if roll < 0.40 and pares_curados:
            id_substancia, id_classe = random.choice(pares_curados)
        elif roll < 0.70:
            id_substancia = str(random.randint(900000, 999999))
            id_classe = random.choice(ids_classe)
        elif roll < 0.90:
            id_substancia = random.choice(ids_substancia)
            id_classe = str(random.randint(900000, 999999))
        else:
            id_substancia = random.choice(ids_substancia)
            id_classe = ""

        linhas.append({"id_substancia": id_substancia, "id_classe_quimica": id_classe})

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=60, help="quantidade total de linhas (curadas + ruído)")
    parser.add_argument("--saida", default="substancia_classe_quimica.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    conn = get_connection()
    ids_substancia = buscar_ids(conn, "substancia")
    ids_classe = buscar_ids(conn, "classe_quimica")
    pares_curados = resolver_pares_curados(conn)
    conn.close()

    linhas = gerar_substancia_classe_quimica(
        n=args.n, ids_substancia=ids_substancia, ids_classe=ids_classe, pares_curados=pares_curados
    )

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["id_substancia", "id_classe_quimica"])
        writer.writeheader()
        writer.writerows(linhas)

    print(
        f"{args.saida} gerado com {len(linhas)} linhas "
        f"({len(pares_curados)} pares curados + {len(linhas) - len(pares_curados)} de ruído)"
    )