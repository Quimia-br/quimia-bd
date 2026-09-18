"""
Quimia — Gerador de dados sintéticos: substancia_sinonimo

Depende de `substancia` já migrada — busca id + nome_canonico reais e
gera variações de grafia/nome comercial pra cada substância (é
literalmente pra isso que a tabela existe: mapear vários jeitos de
escrever pro mesmo composto canônico).

`sinonimo_normalizado` é UNIQUE globalmente na tabela oficial (não
apenas por substância), então o gerador injeta de propósito:
  - sinônimo repetido (mesmo texto saindo 2x, pra testar a rejeição
    por duplicidade dentro do lote e contra a tabela oficial)
  - id_substancia inexistente (pra testar a rejeição por FK)
  - sinônimo vazio (pra testar campo obrigatório)

sinonimo_normalizado NÃO vai no CSV — é calculado no validate/migrate
(lower + remoção de acento + trim), igual já é feito com nome/marca.

Pré-requisito: rodar o pipeline de `substancia` antes deste.

Uso:
    python generate_substancia_sinonimo.py
    python generate_substancia_sinonimo.py --n 300 --saida substancia_sinonimo.csv
"""

import argparse
import csv
import random

from faker import Faker

from src.database.connection import get_connection

fake = Faker("pt_BR")
random.seed(42)

SUFIXOS_COMERCIAIS = [
    "PA", "concentrado", "industrial", "técnico",
    "grau alimentício", "diluído", "solução aquosa",
]


def buscar_substancias(conn):
    """Busca (id, nome_canonico) das substâncias já migradas."""
    cur = conn.cursor()
    cur.execute("SELECT id, nome_canonico FROM substancia")
    resultado = [(str(row[0]), row[1]) for row in cur.fetchall()]
    cur.close()
    return resultado


def gerar_variacao(nome_canonico: str) -> str:
    """Gera uma variação de grafia/nome comercial a partir do nome canônico."""
    tipo = random.choice(["maiuscula", "comercial", "abreviacao", "nome_fantasia"])

    if tipo == "maiuscula":
        return nome_canonico.upper()
    elif tipo == "comercial":
        sufixo = random.choice(SUFIXOS_COMERCIAIS)
        return f"{nome_canonico} {sufixo}"
    elif tipo == "abreviacao":
        partes = nome_canonico.split()
        if len(partes) > 1:
            return f"{partes[0]} {'.'.join(p[0] for p in partes[1:])}."
        return nome_canonico.lower()
    else:
        return f"{fake.word().capitalize()} {nome_canonico.split()[0]}"


def gerar_substancia_sinonimo(n=200, substancias=None):
    if not substancias:
        raise ValueError(
            "Nenhuma substância encontrada na tabela oficial `substancia`. "
            "Rode o pipeline de substancia antes deste."
        )

    linhas = []
    sinonimos_validos_gerados = []
    
    for _ in range(n):
        roll = random.random()
        id_substancia, nome_canonico = random.choice(substancias)

        if roll < 0.80:
            sinonimo = gerar_variacao(nome_canonico)
            sinonimos_validos_gerados.append((id_substancia, sinonimo))

        elif roll < 0.88 and sinonimos_validos_gerados:
            id_substancia, sinonimo = random.choice(sinonimos_validos_gerados)

        elif roll < 0.94:
            sinonimo = gerar_variacao(nome_canonico)
            id_substancia = str(random.randint(900000, 999999))

        else:
            sinonimo = ""

        linhas.append({
            "id_substancia": id_substancia,
            "sinonimo": sinonimo,
        })

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--n", type=int, default=200, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="substancia_sinonimo.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    conn = get_connection()
    substancias = buscar_substancias(conn)
    conn.close()

    linhas = gerar_substancia_sinonimo(n=args.n, substancias=substancias)

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["id_substancia", "sinonimo"])
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas ({len(substancias)} substâncias disponíveis)")