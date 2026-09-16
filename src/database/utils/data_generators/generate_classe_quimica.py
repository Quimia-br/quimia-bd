"""
Quimia — Gerador de dados: classe_quimica

Tabela raiz do dicionário químico, sem FK. Diferente de marca/superficie,
aqui NÃO usamos Faker pra gerar nome — classe química precisa ser dado
real e curado, mesmo em ambiente de teste, porque é a base do match de
incompatibilidade. Lista fechada, não um catálogo aberto.

Uso:
    python generate_classe_quimica.py
    python generate_classe_quimica.py --saida classe_quimica.csv
"""

import argparse
import csv
import random

random.seed(42)

CLASSES_REAIS = [
    ("hipocloritos", "Compostos à base de hipoclorito, ex: água sanitária. Reage com ácidos liberando cloro gasoso."),
    ("acidos", "Substâncias ácidas de uso doméstico, ex: ácido muriático, vinagre concentrado."),
    ("bases", "Substâncias alcalinas/cáusticas, ex: soda cáustica, amônia."),
    ("amonia_aminas", "Amônia e compostos aminados, usados em limpa-vidros e desengraxantes."),
    ("oxidantes", "Agentes oxidantes fortes, ex: peróxido de hidrogênio."),
    #("tensoativos_anionicos", "Surfactantes aniônicos, base de detergentes e sabões."),
    #("tensoativos_nao_ionicos", "Surfactantes não-iônicos, comuns em desengraxantes multiuso."),
    ("solventes_organicos", "Álcoois e solventes, ex: etanol, isopropanol, usados em desinfetantes."),
    ("quaternarios_amonio", "Compostos de amônio quaternário, base de desinfetantes/germicidas."),
    ("fragrancias_aditivos", "Fragrâncias e aditivos sem função de limpeza direta, frequentemente sem CAS declarado."),
]


def gerar_classe_quimica():
    linhas = []

    for nome, descricao in CLASSES_REAIS:
        linhas.append({"nome": nome, "descricao": descricao})

    linhas.append({"nome": "", "descricao": "linha de teste — nome ausente"})

    linhas.append({"nome": "hipocloritos", "descricao": "duplicata proposital pra testar validação"}) #proposital a duplicacao

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--saida", default="classe_quimica.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    linhas = gerar_classe_quimica()

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["nome", "descricao"])
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas")