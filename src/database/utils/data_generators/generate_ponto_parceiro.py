"""
Quimia — Gerador de dados sintéticos: ponto_parceiro

ponto_parceiro.id_empresa é INTEGER e NULLABLE (ponto público sem
empresa vinculada é um caso válido). Quando gerado com empresa, o
gerador PRECISA consultar o banco pra pegar IDs reais.

Uso:
    python generate_ponto_parceiro.py
    # usa DATABASE_URL do ambiente pra buscar IDs reais de empresa

    python generate_ponto_parceiro.py --offline
    # gera IDs fake (sem conectar no banco) — só pra testar a
    # ESTRUTURA do CSV, os IDs não vão bater com nenhum banco real
"""

import argparse
import csv
import os
import random

import psycopg2
from faker import Faker
from dotenv import load_dotenv

load_dotenv()
fake = Faker("pt_BR")
random.seed(42)

UFS = [
    "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA",
    "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN",
    "RS", "RO", "RR", "SC", "SP", "SE", "TO",
]


def buscar_ids_empresa(offline: bool):
    if offline:
        print("[offline] gerando IDs fake — não vão bater com banco real")
        return list(range(1, 31))

    dsn = (
    f"dbname={os.environ['DB_NAME']} "
    f"user={os.environ['DB_USER']} "
    f"password={os.environ['DB_PASSWORD']} "
    f"host={os.environ['DB_HOST']} "
    f"port={os.environ.get('DB_PORT', '5432')}"
    )
    conn = psycopg2.connect(dsn)
    cur = conn.cursor()
    cur.execute("SELECT id FROM empresa")
    ids_empresa = [row[0] for row in cur.fetchall()]
    cur.close()
    conn.close()

    if not ids_empresa:
        raise RuntimeError("Tabela empresa está vazia — rode o dataload de empresa antes.")

    return ids_empresa


def gerar_ponto_parceiro(ids_empresa, n=200):
    linhas = []

    for i in range(n):
        roll = random.random()

        if roll < 0.75:
            id_empresa = random.choice(ids_empresa)
            nome = fake.company()
            cep = fake.postcode()
            estado = random.choice(UFS)
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = ""
            tipo = random.choice(["compra", "descarte"])
            ativo = "true"

        elif roll < 0.85:
            id_empresa = ""
            nome = f"Ponto de coleta {fake.city()}"
            cep = fake.postcode()
            estado = random.choice(UFS)
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = ""
            tipo = "descarte"
            ativo = "true"

        elif roll < 0.90:
            id_empresa = 999999 + i
            nome = fake.company()
            cep = fake.postcode()
            estado = random.choice(UFS)
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = ""
            tipo = random.choice(["compra", "descarte"])
            ativo = "true"

        elif roll < 0.95:
            id_empresa = random.choice(ids_empresa)
            nome = fake.company()
            cep = fake.postcode()
            estado = random.choice(UFS)
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = ""
            tipo = random.choice(["varejo", "atacado", ""])
            ativo = "true"

        else:
            id_empresa = random.choice(ids_empresa)
            nome = ""
            cep = fake.postcode()
            estado = random.choice(UFS)
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = ""
            tipo = random.choice(["compra", "descarte"])
            ativo = "true"

        linhas.append(
            {
                "id_empresa": id_empresa,
                "nome": nome,
                "cep": cep,
                "estado": estado,
                "bairro": bairro,
                "rua": rua,
                "numero": numero,
                "complemento": complemento,
                "tipo": tipo,
                "ativo": ativo,
            }
        )

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true", help="não conecta no banco, gera IDs fake")
    parser.add_argument("--n", type=int, default=200, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="ponto_parceiro.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    ids_empresa = buscar_ids_empresa(args.offline)
    linhas = gerar_ponto_parceiro(ids_empresa, n=args.n)

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "id_empresa", "nome", "cep", "estado", "bairro",
                "rua", "numero", "complemento", "tipo", "ativo",
            ],
        )
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas")