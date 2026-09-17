"""
Quimia — Gerador de dados sintéticos: estante

Depende de usuario (FK id_usuario) — busca os UUIDs já migrados na
tabela oficial `usuario` pra gerar estantes plausíveis. Também injeta
uma fatia de linhas propositalmente inválidas (usuário inexistente,
uuid mal formado, nome vazio) pra dar trabalho de verdade pro validate.

Pré-requisito: rodar o pipeline de `usuario` antes deste.

Uso:
    python generate_estante.py
    python generate_estante.py --n 300 --saida estante.csv
"""

import argparse
import csv
import random
import uuid

from faker import Faker

from src.database.connection import get_connection

fake = Faker("pt_BR")
random.seed(42)

AMBIENTES = [
    "Cozinha", "Banheiro", "Lavanderia", "Área de serviço",
    "Quintal", "Garagem", "Sala", "Quarto", "Despensa",
]


def buscar_usuarios_existentes(conn):
    """Busca os UUIDs já migrados na tabela oficial `usuario`."""
    cur = conn.cursor()
    cur.execute("SELECT id FROM usuario")
    ids = [str(row[0]) for row in cur.fetchall()]
    cur.close()
    return ids


def gerar_nome_estante(ambiente):
    padroes = [
        f"Estante {ambiente}",
        f"Armário {ambiente}",
        f"Prateleira {ambiente.lower()}",
    ]
    return random.choice(padroes)


def gerar_estante(n=100, ids_usuario=None):
    if not ids_usuario:
        raise ValueError(
            "Nenhum usuário encontrado na tabela oficial `usuario`. "
            "Rode o pipeline de usuario antes de gerar estante."
        )

    linhas = []
    for _ in range(n):
        roll = random.random()
        ambiente = random.choice(AMBIENTES)

 
        if roll < 0.85:
            id_usuario = random.choice(ids_usuario)
        elif roll < 0.93:
            id_usuario = str(uuid.uuid4())
        elif roll < 0.97:
            id_usuario = "uuid-invalido-123"      
        else:
            id_usuario = ""                   

        nome = gerar_nome_estante(ambiente) if random.random() < 0.92 else ""

        linhas.append({
            "id_usuario": id_usuario,
            "nome": nome,
            "ambiente": ambiente,
        })

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=100, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="estante.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    conn = get_connection()
    ids_usuario = buscar_usuarios_existentes(conn)
    conn.close()

    linhas = gerar_estante(n=args.n, ids_usuario=ids_usuario)

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["id_usuario", "nome", "ambiente"])
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas ({len(ids_usuario)} usuários disponíveis)")