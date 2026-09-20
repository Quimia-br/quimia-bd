"""
Quimia — Gerador de dados sintéticos: historico_recomendacao

Depende de produto, usuario e superficie já migrados — busca os IDs
reais do banco antes de gerar. Simula o log de "usuário consultou o
app pra saber se o produto X é compatível com a superfície Y".

Ruído proposital pro validate:
  - id_produto / id_usuario inexistentes ou com formato inválido
  - id_superficie inexistente (quando informado)
  - resultado fora do CHECK da tabela oficial
  - campos obrigatórios vazios

Pré-requisito: rodar os pipelines de `produto`, `usuario` e
`superficie` antes deste.

Uso:
    python generate_historico_recomendacao.py
    python generate_historico_recomendacao.py --n 500 --saida historico_recomendacao.csv
"""

import argparse
import csv
import random
import uuid

from src.database.connection import get_connection

random.seed(42)

RESULTADOS_VALIDOS = ["compativel", "incompativel", "atencao", "nao_avaliado"]
RESULTADOS_INVALIDOS = ["talvez", "compatível!", "ok", ""]

DOSAGENS_SUGERIDAS = [
    "1 tampa (30ml) para 5L de água",
    "2 colheres de sopa puro",
    "Diluir 1:10 em água morna",
    "Aplicar puro, sem diluição",
    "1 colher de chá para 1L de água",
    "",
]


def buscar_ids(conn, tabela):
    cur = conn.cursor()
    cur.execute(f"SELECT id FROM {tabela}")
    ids = [str(row[0]) for row in cur.fetchall()]
    cur.close()
    return ids


def buscar_usuarios(conn):
    cur = conn.cursor()
    cur.execute("SELECT id FROM usuario")
    ids = [str(row[0]) for row in cur.fetchall()]
    cur.close()
    return ids


def gerar_historico_recomendacao(n=300, ids_produto=None, ids_usuario=None, ids_superficie=None):
    if not ids_produto:
        raise ValueError(
            "Nenhum produto encontrado na tabela oficial `produto`. "
            "Rode o pipeline de produto antes deste."
        )
    if not ids_usuario:
        raise ValueError(
            "Nenhum usuário encontrado na tabela oficial `usuario`. "
            "Rode o pipeline de usuario antes deste."
        )
    if not ids_superficie:
        raise ValueError(
            "Nenhuma superfície encontrada na tabela oficial `superficie`. "
            "Rode o pipeline de superficie antes deste."
        )

    linhas = []
    for _ in range(n):
        roll = random.random()

        if roll < 0.88:
            id_produto = random.choice(ids_produto)
        elif roll < 0.95:
            id_produto = str(random.randint(900000, 999999))
        elif roll < 0.98:
            id_produto = "produto-x"
        else:
            id_produto = ""

        roll_u = random.random()
        if roll_u < 0.88:
            id_usuario = random.choice(ids_usuario)
        elif roll_u < 0.95:
            id_usuario = str(uuid.uuid4())
        elif roll_u < 0.98:
            id_usuario = "usuario-invalido"
        else:
            id_usuario = ""

        roll_s = random.random()
        if roll_s < 0.75:
            id_superficie = random.choice(ids_superficie)
        elif roll_s < 0.85:
            id_superficie = ""
        elif roll_s < 0.95:
            id_superficie = str(random.randint(900000, 999999))
        else:
            id_superficie = "superficie-x" 

        roll_r = random.random()
        if roll_r < 0.85:
            resultado = random.choice(RESULTADOS_VALIDOS)
        elif roll_r < 0.93:
            resultado = random.choice(RESULTADOS_INVALIDOS)
        else:
            resultado = ""

        dosagem_sugerida = random.choice(DOSAGENS_SUGERIDAS)

        linhas.append({
            "id_produto": id_produto,
            "id_usuario": id_usuario,
            "id_superficie": id_superficie,
            "resultado": resultado,
            "dosagem_sugerida": dosagem_sugerida,
        })

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=300, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="historico_recomendacao.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    conn = get_connection()
    ids_produto = buscar_ids(conn, "produto")
    ids_usuario = buscar_usuarios(conn)
    ids_superficie = buscar_ids(conn, "superficie")
    conn.close()

    linhas = gerar_historico_recomendacao(
        n=args.n,
        ids_produto=ids_produto,
        ids_usuario=ids_usuario,
        ids_superficie=ids_superficie,
    )

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f, fieldnames=["id_produto", "id_usuario", "id_superficie", "resultado", "dosagem_sugerida"]
        )
        writer.writeheader()
        writer.writerows(linhas)

    print(
        f"{args.saida} gerado com {len(linhas)} linhas "
        f"({len(ids_produto)} produtos, {len(ids_usuario)} usuários, {len(ids_superficie)} superfícies disponíveis)"
    )