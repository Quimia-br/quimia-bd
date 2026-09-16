"""
Quimia — Gerador de dados: substancia

Tabela raiz do dicionário químico. Assim como classe_quimica, usa
lista curada com CAS numbers reais — não é dado sintético aleatório,
é a base do match de incompatibilidade.

cas_numero é NULLABLE de propósito: nem todo composto tem CAS
(ex: "FRAGRANCIA", caso real encontrado na FDS Minuano).

Uso:
    python generate_substancia.py
    python generate_substancia.py --saida substancia.csv
"""

import argparse
import csv

# (nome_canonico, cas_numero ou None, descricao)
SUBSTANCIAS_REAIS = [
    ("Hipoclorito de sódio", "7681-52-9", "Agente clorado ativo em água sanitária."),
    ("Amônia", "7664-41-7", "Base usada em limpa-vidros e desengraxantes."),
    ("Ácido clorídrico", "7647-01-0", "Ácido forte, base do ácido muriático."),
    ("Ácido acético", "64-19-7", "Ácido orgânico, componente de vinagre concentrado."),
    ("Hidróxido de sódio", "1310-73-2", "Base forte (soda cáustica)."),
    ("Peróxido de hidrogênio", "7722-84-1", "Agente oxidante, alvejante e desinfetante."),
    ("Etanol", "64-17-5", "Álcool usado como solvente e desinfetante."),
    ("Álcool isopropílico", "67-63-0", "Solvente e desinfetante de uso doméstico."),
    ("Lauril sulfato de sódio", "151-21-3", "Tensoativo aniônico, base de detergentes."),
    ("Cloreto de benzalcônio", "63449-41-2", "Quaternário de amônio, germicida."),
    ("Hipoclorito de cálcio", "7778-54-3", "Agente clorado sólido, uso em piscinas e desinfecção pesada."),
    ("Ácido fosfórico", "7664-38-2", "Ácido usado em removedores de crosta/calcário."),
    ("Ácido cítrico", "77-92-9", "Ácido orgânico fraco, uso em antical natural."),
    ("Dodecilbenzenossulfonato de sódio", "25155-30-0", "Tensoativo aniônico comum em detergentes multiuso."),
    ("Fragrância", None, "Composto proprietário sem CAS declarado — caso real (FDS Minuano)."),
]


def gerar_substancia():
    linhas = []

    for nome, cas, descricao in SUBSTANCIAS_REAIS:
        linhas.append({"nome_canonico": nome, "cas_numero": cas or "", "descricao": descricao})

    # sujeira proposital

    # nome vazio
    linhas.append({"nome_canonico": "", "cas_numero": "999-99-9", "descricao": "linha de teste — nome ausente"})

    # cas malformado
    linhas.append(
        {"nome_canonico": "Substância teste CAS malformado", "cas_numero": "abc-def", "descricao": "cas inválido de propósito"}
    )

    # cas duplicado de propósito (reaproveita um já usado)
    linhas.append(
        {"nome_canonico": "Hipoclorito de sódio (duplicata)", "cas_numero": "7681-52-9", "descricao": "duplicata proposital de CAS"}
    )

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--saida", default="substancia.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    linhas = gerar_substancia()

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["nome_canonico", "cas_numero", "descricao"])
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas")