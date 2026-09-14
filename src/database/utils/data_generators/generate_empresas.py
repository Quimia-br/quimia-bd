"""
Quimia — Gerador de dados sintéticos (Faker) para dataload via staging.
Gera CSVs de `usuario` e `empresa`, com uma fração deliberada de linhas
"sujas" para exercitar a validação em SQL do staging (mesmo padrão
já validado antes: e-mail inválido, CNPJ malformado, duplicata dentro
do lote, campo vazio).

Uso:
    python gerar_dados_usuario_empresa.py

Saída:
    empresa.csv  (500 linhas, ~90% válidas)
"""




import csv
import random
from datetime import datetime, timedelta

from faker import Faker

fake = Faker("pt_BR")
random.seed(42)

N_EMPRESA = 500


def gerar_cnpj_valido():
    return fake.cnpj()


def gerar_cnpj_invalido():
    opcoes = [
        "12.345",
        "00.000.000/0000-00",    
        "não tem cnpj",
        "",
    ]
    return random.choice(opcoes)


empresas = []
cnpjs_usados = set()

for i in range(N_EMPRESA):
    roll = random.random()

    if roll < 0.85:
        nome = fake.company()
        cnpj = fake.unique.cnpj()
        ativo = random.choice(["true", "true", "true", "false"])

    elif roll < 0.92:
        nome = fake.company()
        cnpj = gerar_cnpj_invalido()
        ativo = random.choice(["true", "false"])

    elif roll < 0.96:
        nome = ""
        cnpj = fake.unique.cnpj()
        ativo = random.choice(["true", "false"])

    else:
        nome = fake.company()
        cnpj = random.choice(list(cnpjs_usados)) if cnpjs_usados else fake.unique.cnpj()
        ativo = random.choice(["true", "false"])

    cnpjs_usados.add(cnpj)
    empresas.append({"nome": nome, "cnpj": cnpj, "ativo": ativo})

with open("empresa.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["nome", "cnpj", "ativo"])
    writer.writeheader()
    writer.writerows(empresas)

print(f"empresa.csv gerado com {len(empresas)} linhas")