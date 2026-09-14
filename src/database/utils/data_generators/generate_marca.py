"""
Quimia — Gerador de dados sintéticos: marca

Tabela raiz, sem FK — não depende de banco pra gerar.

Uso:
    python generate_marca.py
    python generate_marca.py --n 100 --saida marca.csv
"""

import argparse
import csv
import random

from faker import Faker

fake = Faker("pt_BR")
random.seed(42)


def gerar_marca(n=100):
    linhas = []
    nomes_usados = set()

    for i in range(n):
        roll = random.random()

        if roll < 0.90:
            nome = fake.unique.company()

        else:
            nome = random.choice(["", "   "])

        linhas.append({"nome": nome})

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=100, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="marca.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    linhas = gerar_marca(n=args.n)

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["nome"])
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas")