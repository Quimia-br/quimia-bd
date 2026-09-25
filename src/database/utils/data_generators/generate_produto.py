"""
Quimia — Gerador de dados sintéticos: produto

Depende de marca já migrada — busca os IDs reais do banco antes de
gerar. Também injeta ruído proposital pra exercitar o validate:
  - id_marca inexistente / formato inválido / vazio
  - nome vazio
  - tipo_produto fora do CHECK da tabela oficial
  - cod_barras duplicado (dentro do lote)
  - foto_url com formato inválido

Pré-requisito: rodar o pipeline de `marca` antes deste.

Uso:
    python generate_produto.py
    python generate_produto.py --n 300 --saida produto.csv
"""

import argparse
import csv
import random

from faker import Faker

from src.database.connection import get_connection

fake = Faker("pt_BR")
random.seed(42)

TIPOS_PRODUTO = [
    "limpeza_geral", "desinfetante", "desincrustante",
    "desengraxante", "alvejante", "aromatizante", "outro",
]

TIPOS_INVALIDOS = ["multiuso", "premium", "concentrado_xl", ""]

PREFIXOS_NOME = [
    "Detergente", "Desinfetante", "Multiuso", "Desengraxante",
    "Alvejante", "Limpa Vidros", "Sabão Líquido", "Amaciante",
    "Água Sanitária", "Removedor", "Limpador",
]

SUFIXOS_NOME = [
    "Concentrado", "Ultra", "Gel", "Spray", "Tradicional",
    "Frescor", "Cítrico", "Lavanda", "Profissional", "Max",
]


def buscar_marcas(conn):
    cur = conn.cursor()
    cur.execute("SELECT id FROM marca")
    ids = [str(row[0]) for row in cur.fetchall()]
    cur.close()
    return ids


def gerar_nome_produto():
    return f"{random.choice(PREFIXOS_NOME)} {random.choice(SUFIXOS_NOME)}"


def gerar_foto_url(valida=True):
    if not valida:
        return "nao_e_uma_url"
    roll = random.random()
    if roll < 0.80:
        return f"https://picsum.photos/seed/{random.randint(1, 100000)}/400/400.jpg"
    return ""


def gerar_produto(n=200, ids_marca=None):
    if not ids_marca:
        raise ValueError(
            "Nenhuma marca encontrada na tabela oficial `marca`. "
            "Rode o pipeline de marca antes deste."
        )

    linhas = []
    cod_barras_usados = []

    for _ in range(n):
        roll = random.random()

        if roll < 0.85:
            id_marca = random.choice(ids_marca)
        elif roll < 0.92:
            id_marca = str(random.randint(900000, 999999))
        elif roll < 0.96:
            id_marca = "marca-x"
        else:
            id_marca = ""

        nome = gerar_nome_produto() if random.random() < 0.94 else ""

        descricao = fake.sentence(nb_words=10) if random.random() < 0.7 else ""

        roll_tipo = random.random()
        if roll_tipo < 0.85:
            tipo_produto = random.choice(TIPOS_PRODUTO)
        elif roll_tipo < 0.93:
            tipo_produto = random.choice(TIPOS_INVALIDOS)
        else:
            tipo_produto = ""

        if cod_barras_usados and random.random() < 0.08:
            cod_barras = random.choice(cod_barras_usados)
        else:
            cod_barras = fake.ean13()
            cod_barras_usados.append(cod_barras)

        if random.random() < 0.1:
            cod_barras = ""

        roll_foto = random.random()
        if roll_foto < 0.85:
            foto_url = gerar_foto_url(valida=True)
        else:
            foto_url = gerar_foto_url(valida=False)

        linhas.append({
            "nome": nome,
            "id_marca": id_marca,
            "descricao": descricao,
            "tipo_produto": tipo_produto,
            "cod_barras": cod_barras,
            "foto_url": foto_url,
        })

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=200, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="produto.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    conn = get_connection()
    ids_marca = buscar_marcas(conn)
    conn.close()

    linhas = gerar_produto(n=args.n, ids_marca=ids_marca)

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f, fieldnames=["nome", "id_marca", "descricao", "tipo_produto", "cod_barras", "foto_url"]
        )
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas ({len(ids_marca)} marcas disponíveis)")