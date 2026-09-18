"""
Quimia — Gerador de dados sintéticos: substancia_classe_quimica

Tabela de junção N:N entre substancia e classe_quimica. Depende das
duas tabelas já estarem migradas — busca os IDs reais do banco antes
de gerar as combinações.

A tabela oficial tem UNIQUE(id_substancia, id_classe_quimica), então o
gerador injeta de propósito:
  - pares duplicados (pra exercitar a rejeição por duplicidade)
  - IDs inexistentes dos dois lados (pra exercitar a rejeição por FK)
  - id_classe_quimica vazio (pra exercitar a rejeição por campo obrigatório)

Pré-requisito: rodar os pipelines de `substancia` e `classe_quimica`
antes deste.

Uso:
    python generate_substancia_classe_quimica.py
    python generate_substancia_classe_quimica.py --n 300 --saida substancia_classe_quimica.csv
"""

import argparse
import csv
import random

from src.database.connection import get_connection

random.seed(42)


def buscar_ids(conn, tabela):
    cur = conn.cursor()
    cur.execute(f"SELECT id FROM {tabela}")
    ids = [str(row[0]) for row in cur.fetchall()]
    cur.close()
    return ids


def gerar_substancia_classe_quimica(n=200, ids_substancia=None, ids_classe=None):
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

    linhas = []
    pares_validos_gerados = []  

    for _ in range(n):
        roll = random.random()

        if roll < 0.78:
            id_substancia = random.choice(ids_substancia)
            id_classe = random.choice(ids_classe)
            pares_validos_gerados.append((id_substancia, id_classe))

        elif roll < 0.86 and pares_validos_gerados:
            id_substancia, id_classe = random.choice(pares_validos_gerados)

        elif roll < 0.92:
            id_substancia = str(random.randint(900000, 999999))
            id_classe = random.choice(ids_classe)

        elif roll < 0.97:
            id_substancia = random.choice(ids_substancia)
            id_classe = str(random.randint(900000, 999999))

        else:
            id_substancia = random.choice(ids_substancia)
            id_classe = ""

        linhas.append({
            "id_substancia": id_substancia,
            "id_classe_quimica": id_classe,
        })

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=200, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="substancia_classe_quimica.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    conn = get_connection()
    ids_substancia = buscar_ids(conn, "substancia")
    ids_classe = buscar_ids(conn, "classe_quimica")
    conn.close()

    linhas = gerar_substancia_classe_quimica(
        n=args.n, ids_substancia=ids_substancia, ids_classe=ids_classe
    )

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["id_substancia", "id_classe_quimica"])
        writer.writeheader()
        writer.writerows(linhas)

    print(
        f"{args.saida} gerado com {len(linhas)} linhas "
        f"({len(ids_substancia)} substâncias, {len(ids_classe)} classes disponíveis)"
    )