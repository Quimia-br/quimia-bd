"""
Quimia — Gerador de dados sintéticos (Faker) para dataload via staging.
Gera CSVs de `usuario` e `empresa`, com uma fração deliberada de linhas
"sujas" para exercitar a validação em SQL do staging (mesmo padrão
já validado antes: e-mail inválido, CNPJ malformado, duplicata dentro
do lote, campo vazio).

Uso:
    python gerar_dados_usuario_empresa.py

Saída:
    usuario.csv  (1000 linhas, ~92% válidas)
"""

import csv
import random
from datetime import datetime, timedelta

from faker import Faker

fake = Faker("pt_BR")
random.seed(42)

N_USUARIO = 1000
NIVEIS_VALIDOS = ["usuario", "usuario", "usuario", "usuario", "empresa", "admin"]  # pesa pra 'usuario'


def gerar_email_valido(nome):
    return fake.unique.email()


def gerar_email_invalido():
    opcoes = [
        f"{fake.first_name().lower()}@@dominio.com",
        f"{fake.first_name().lower()}sem-arroba.com",
        f"{fake.first_name().lower()}@dominio",
        "   ",
        "",
    ]
    return random.choice(opcoes)


def gerar_data_nasc(valida=True):
    if not valida:
        return random.choice(["31/02/2000", "0000-00-00", "amanha", ""])
    dt = fake.date_of_birth(minimum_age=16, maximum_age=90)
    return dt.isoformat()


def gerar_ultima_sessao():
    if random.random() < 0.15:
        return ""
    dt = fake.date_time_between(start_date="-90d", end_date="now")
    return dt.strftime("%Y-%m-%d %H:%M:%S")


usuarios = []
emails_usados = set()

for i in range(N_USUARIO):
    roll = random.random()

    if roll < 0.80:
        nome = fake.name()
        email = fake.unique.email()
        data_nasc = gerar_data_nasc(valida=True)
        nivel_acesso = random.choice(NIVEIS_VALIDOS)
        ultima_sessao = gerar_ultima_sessao()

    elif roll < 0.86:
        nome = fake.name()
        email = gerar_email_invalido()
        data_nasc = gerar_data_nasc(valida=True)
        nivel_acesso = random.choice(NIVEIS_VALIDOS)
        ultima_sessao = gerar_ultima_sessao()

    elif roll < 0.90:
        nome = random.choice(["", "   "])
        email = fake.unique.email()
        data_nasc = gerar_data_nasc(valida=True)
        nivel_acesso = random.choice(NIVEIS_VALIDOS)
        ultima_sessao = gerar_ultima_sessao()

    elif roll < 0.94:
        nome = fake.name()
        email = fake.unique.email()
        data_nasc = gerar_data_nasc(valida=True)
        nivel_acesso = random.choice(["superusuario", "root", "", "ADMIN "])
        ultima_sessao = gerar_ultima_sessao()

    elif roll < 0.97:
        nome = fake.name()
        email = fake.unique.email()
        data_nasc = gerar_data_nasc(valida=False)
        nivel_acesso = random.choice(NIVEIS_VALIDOS)
        ultima_sessao = gerar_ultima_sessao()

    else:
        nome = fake.name()
        email = random.choice(list(emails_usados)) if emails_usados else fake.unique.email()
        data_nasc = gerar_data_nasc(valida=True)
        nivel_acesso = random.choice(NIVEIS_VALIDOS)
        ultima_sessao = gerar_ultima_sessao()

    emails_usados.add(email)
    usuarios.append(
        {
            "nome": nome,
            "email": email,
            "data_nasc": data_nasc,
            "nivel_acesso": nivel_acesso,
            "ultima_sessao": ultima_sessao,
        }
    )

with open("usuario.csv", "w", newline="", encoding="utf-8") as f:
    writer = csv.DictWriter(f, fieldnames=["nome", "email", "data_nasc", "nivel_acesso", "ultima_sessao"])
    writer.writeheader()
    writer.writerows(usuarios)

print(f"usuario.csv gerado com {len(usuarios)} linhas")


