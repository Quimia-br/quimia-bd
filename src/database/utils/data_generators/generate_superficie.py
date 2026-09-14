"""
Quimia — Gerador de dados sintéticos: superficie

Tabela raiz, sem FK — não depende de banco pra gerar.

Uso:
    python generate_superficie.py
    python generate_superficie.py --n 30 --saida superficie.csv
"""

import argparse
import csv
import random

from faker import Faker

fake = Faker("pt_BR")
random.seed(42)

SUPERFICIES_REAIS = [
    "Mármore", "Granito", "Cerâmica", "Porcelanato", "Madeira",
    "Vidro", "Aço inoxidável", "Plástico", "Tecido/Estofado",
    "Couro", "Concreto", "Azulejo", "Laminado", "Alumínio", "Pedra natural",
    "MDF", "MDP", "Laminado", "Vinílico", "Quartzo"
]


def gerar_superficie(n=15):
    linhas = []
    n = min(n, len(SUPERFICIES_REAIS) + 5)

    for i in range(n):
        roll = random.random()

        if i < len(SUPERFICIES_REAIS) and roll < 0.90:
            nome = SUPERFICIES_REAIS[i]
            descricao = fake.sentence(nb_words=8)

        elif roll < 0.95:
            nome = random.choice(["", "   "])
            descricao = fake.sentence(nb_words=8)

        else:
            nome = random.choice(SUPERFICIES_REAIS)
            descricao = fake.sentence(nb_words=8)

        linhas.append({"nome": nome, "descricao": descricao})

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=15, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="superficie.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    linhas = gerar_superficie(n=args.n)

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["nome", "descricao"])
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas")