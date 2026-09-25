"""
Quimia — Gerador de dados sintéticos: empresa

Tabela raiz, sem FK — não depende de banco pra gerar.
Tem autenticação própria (senha) e foto de perfil (foto_url),
mesma lógica de usuario: senha nunca sai em texto puro, só o hash
bcrypt (60 caracteres).

Uso:
    python generate_empresa.py
    python generate_empresa.py --n 50 --saida empresa.csv

Dependência: bcrypt (pip install bcrypt)
"""

import argparse
import csv
import random

import bcrypt
from faker import Faker

fake = Faker("pt_BR")
random.seed(42)


def gerar_cnpj_invalido():
    opcoes = [
        "12.345.678/0001",
        "00000000000000", 
        "abc.def.ghi/jklm-no",
        "",
    ]
    return random.choice(opcoes)


def gerar_senha_hash(valida=True):
    """
    Gera uma senha fake em texto e devolve o hash bcrypt (60 chars).
    Nunca grava a senha em texto no CSV.
    """
    if not valida:
        return random.choice(["", "hash-invalido-123", "   "])

    senha_texto = fake.password(length=12)
    hash_bytes = bcrypt.hashpw(senha_texto.encode("utf-8"), bcrypt.gensalt())
    return hash_bytes.decode("utf-8")


def gerar_foto_url(valida=True):
    if not valida:
        return "nao_e_uma_url"
    roll = random.random()
    if roll < 0.70:
        return f"https://i.pravatar.cc/300?u={fake.uuid4()}"
    return ""  # sem foto cadastrada — opcional


def gerar_empresa(n=50):
    linhas = []
    cnpjs_usados = []

    for _ in range(n):
        roll = random.random()

        if roll < 0.80:
            nome = fake.company()
            cnpj = fake.cnpj()
            ativo = random.choice(["true", "true", "true", "false"])
            senha = gerar_senha_hash(valida=True)
            foto_url = gerar_foto_url(valida=True)
            cnpjs_usados.append(cnpj)

        elif roll < 0.86:
            nome = random.choice(["", "   "])
            cnpj = fake.cnpj()
            ativo = "true"
            senha = gerar_senha_hash(valida=True)
            foto_url = gerar_foto_url(valida=True)

        elif roll < 0.90:
            nome = fake.company()
            cnpj = gerar_cnpj_invalido()
            ativo = "true"
            senha = gerar_senha_hash(valida=True)
            foto_url = gerar_foto_url(valida=True)

        elif roll < 0.94 and cnpjs_usados:
            nome = fake.company()
            cnpj = random.choice(cnpjs_usados)
            ativo = "true"
            senha = gerar_senha_hash(valida=True)
            foto_url = gerar_foto_url(valida=True)

        elif roll < 0.97:
            nome = fake.company()
            cnpj = fake.cnpj()
            ativo = "true"
            senha = gerar_senha_hash(valida=False)
            foto_url = gerar_foto_url(valida=True)
            cnpjs_usados.append(cnpj)

        else:
            nome = fake.company()
            cnpj = fake.cnpj()
            ativo = "true"
            senha = gerar_senha_hash(valida=True)
            foto_url = gerar_foto_url(valida=False)
            cnpjs_usados.append(cnpj)

        linhas.append({
            "nome": nome,
            "cnpj": cnpj,
            "ativo": ativo,
            "senha": senha,
            "foto_url": foto_url,
        })

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=50, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="empresa.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    linhas = gerar_empresa(n=args.n)

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["nome", "cnpj", "ativo", "senha", "foto_url"])
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas")