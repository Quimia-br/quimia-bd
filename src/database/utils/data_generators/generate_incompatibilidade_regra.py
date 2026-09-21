"""
Quimia — Gerador de dados sintéticos: incompatibilidade_regra

Depende de substancia e classe_quimica já migradas. Cada lado (A e B)
da regra precisa ser EXATAMENTE substancia OU classe (nunca os dois,
nunca nenhum) — regra espelhada no CHECK da tabela oficial.

NOTA (pendência conhecida): igual em substancia_classe_quimica, o
sorteio de pares aqui é aleatório, sem afinidade química real — serve
pra validar integridade/formato do pipeline, não o conteúdo. Regras
quimicamente coerentes (ex: "ácido + hipoclorito = gás tóxico") devem
ser curadas manualmente quando entrar FDS real, já que essa tabela
alimenta o fn_match_produtos.

Ruído proposital pro validate:
  - lado A/B com os dois preenchidos (viola XOR)
  - lado A/B com nenhum preenchido (viola XOR)
  - severidade fora do CHECK
  - descricao_risco vazia
  - id inexistente / formato inválido

Pré-requisito: rodar os pipelines de `substancia` e `classe_quimica`
antes deste.

Uso:
    python generate_incompatibilidade_regra.py
    python generate_incompatibilidade_regra.py --n 150 --saida incompatibilidade_regra.csv
"""

import argparse
import csv
import random

from faker import Faker

from src.database.connection import get_connection

fake = Faker("pt_BR")
random.seed(42)

SEVERIDADES_VALIDAS = ["baixa", "media", "alta", "critica"]
SEVERIDADES_INVALIDAS = ["moderada", "extrema", "leve", ""]

DESCRICOES_RISCO = [
    "Reação exotérmica com liberação de calor intenso.",
    "Formação de gás tóxico (ex: cloro) ao entrar em contato.",
    "Risco de explosão em ambientes confinados.",
    "Liberação de vapores irritantes às vias respiratórias.",
    "Corrosão acelerada de superfícies metálicas.",
    "Reação pode causar queimaduras químicas por contato.",
]


def buscar_ids(conn, tabela):
    cur = conn.cursor()
    cur.execute(f"SELECT id FROM {tabela}")
    ids = [str(row[0]) for row in cur.fetchall()]
    cur.close()
    return ids


def sortear_lado(ids_substancia, ids_classe, forcar_erro=None):
    """
    Sorteia um lado (A ou B) da regra, respeitando o XOR na maioria
    dos casos, mas podendo forçar um erro específico pro validate:
      forcar_erro=None        -> válido (substância OU classe, sorteado)
      forcar_erro="ambos"     -> substância E classe preenchidos (viola XOR)
      forcar_erro="nenhum"    -> nenhum preenchido (viola XOR)
    Retorna (id_substancia, id_classe).
    """
    if forcar_erro == "ambos":
        return random.choice(ids_substancia), random.choice(ids_classe)
    if forcar_erro == "nenhum":
        return "", ""

    if random.random() < 0.5:
        return random.choice(ids_substancia), ""
    else:
        return "", random.choice(ids_classe)


def gerar_incompatibilidade_regra(n=150, ids_substancia=None, ids_classe=None):
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
    for _ in range(n):
        roll = random.random()

        if roll < 0.85:
            erro_a, erro_b = None, None
        elif roll < 0.91:
            erro_a, erro_b = "ambos", None
        elif roll < 0.97:
            erro_a, erro_b = None, "nenhum"
        else:
            erro_a, erro_b = "ambos", "nenhum"

        id_substancia_a, id_classe_a = sortear_lado(ids_substancia, ids_classe, erro_a)
        id_substancia_b, id_classe_b = sortear_lado(ids_substancia, ids_classe, erro_b)

        roll_sev = random.random()
        if roll_sev < 0.85:
            severidade = random.choice(SEVERIDADES_VALIDAS)
        elif roll_sev < 0.94:
            severidade = random.choice(SEVERIDADES_INVALIDAS)
        else:
            severidade = ""

        descricao_risco = random.choice(DESCRICOES_RISCO) if random.random() < 0.93 else ""

        fonte = "NBR 14725" if random.random() < 0.6 else ""

        roll_ativo = random.random()
        if roll_ativo < 0.85:
            ativo = random.choice(["true", "false"])
        elif roll_ativo < 0.95:
            ativo = ""
        else:
            ativo = "sim"

        linhas.append({
            "id_substancia_a": id_substancia_a,
            "id_classe_a": id_classe_a,
            "id_substancia_b": id_substancia_b,
            "id_classe_b": id_classe_b,
            "severidade": severidade,
            "descricao_risco": descricao_risco,
            "fonte": fonte,
            "ativo": ativo,
        })

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=150, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="incompatibilidade_regra.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    conn = get_connection()
    ids_substancia = buscar_ids(conn, "substancia")
    ids_classe = buscar_ids(conn, "classe_quimica")
    conn.close()

    linhas = gerar_incompatibilidade_regra(
        n=args.n, ids_substancia=ids_substancia, ids_classe=ids_classe
    )

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "id_substancia_a", "id_classe_a",
                "id_substancia_b", "id_classe_b",
                "severidade", "descricao_risco", "fonte", "ativo",
            ],
        )
        writer.writeheader()
        writer.writerows(linhas)

    print(
        f"{args.saida} gerado com {len(linhas)} linhas "
        f"({len(ids_substancia)} substâncias, {len(ids_classe)} classes disponíveis)"
    )