"""
Quimia — Gerador de dados sintéticos: localizacao_usuario

localizacao_usuario.id_usuario é UUID e obrigatório -- o gerador
PRECISA consultar o banco pra pegar UUIDs reais já carregados em
usuario, não dá pra inventar.

Uso:
    python generate_localizacao_usuario.py
    # usa DATABASE_URL do ambiente pra buscar IDs reais de usuario

    python generate_localizacao_usuario.py --offline
    # gera IDs fake (sem conectar no banco) — só pra testar a
    # ESTRUTURA do CSV, os IDs não vão bater com nenhum banco real
"""

import argparse
import csv
import os
import random
import uuid

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


CENTROS_UF = {
    "AC": (-9.97, -67.81), "AL": (-9.67, -35.74), "AP": (0.03, -51.07),
    "AM": (-3.12, -60.02), "BA": (-12.97, -38.51), "CE": (-3.73, -38.52),
    "DF": (-15.78, -47.93), "ES": (-20.32, -40.34), "GO": (-16.68, -49.25),
    "MA": (-2.53, -44.30), "MT": (-15.60, -56.10), "MS": (-20.47, -54.62),
    "MG": (-19.92, -43.94), "PA": (-1.46, -48.50), "PB": (-7.12, -34.86),
    "PR": (-25.43, -49.27), "PE": (-8.05, -34.88), "PI": (-5.09, -42.80),
    "RJ": (-22.91, -43.17), "RN": (-5.79, -35.21), "RS": (-30.03, -51.23),
    "RO": (-8.76, -63.90), "RR": (2.82, -60.67), "SC": (-27.59, -48.55),
    "SP": (-23.55, -46.63), "SE": (-10.91, -37.07), "TO": (-10.18, -48.33),
}


def gerar_coordenadas(estado):
    """
    Devolve (latitude, longitude) como texto, no formato do CSV. Colunas opcionais:
      87% válidas | 6% vazias (válido, usuário não informou) | 3% fora da faixa |
      2% não numéricas (vírgula decimal) | 2% só uma das duas (rejeitada: têm que vir juntas)
    Estado inválido ("sao paulo", "") cai num centro aleatório, só pra ter o que sortear.
    """
    lat0, lon0 = CENTROS_UF.get(estado) or random.choice(list(CENTROS_UF.values()))
    lat = lat0 + random.uniform(-0.25, 0.25)
    lon = lon0 + random.uniform(-0.25, 0.25)
    roll = random.random()

    if roll < 0.87:
        return f"{lat:.6f}", f"{lon:.6f}"
    if roll < 0.93:
        return "", ""
    if roll < 0.96:
        return random.choice([("123.456789", f"{lon:.6f}"), (f"{lat:.6f}", "-250.5"), ("-95.0", "200.0")])
    if roll < 0.98:
        return f"{lat:.6f}".replace(".", ","), f"{lon:.6f}".replace(".", ",")
    return random.choice([(f"{lat:.6f}", ""), ("", f"{lon:.6f}")])


def buscar_ids_usuario(offline: bool):
    if offline:
        print("[offline] gerando IDs fake — não vão bater com banco real")
        return [str(uuid.uuid4()) for _ in range(50)]

    dsn = (
    f"dbname={os.environ['DB_NAME']} "
    f"user={os.environ['DB_USER']} "
    f"password={os.environ['DB_PASSWORD']} "
    f"host={os.environ['DB_HOST']} "
    f"port={os.environ.get('DB_PORT', '5432')}"
    )
    conn = psycopg2.connect(dsn)
    cur = conn.cursor()
    cur.execute("SELECT id FROM usuario")
    ids_usuario = [str(row[0]) for row in cur.fetchall()]
    cur.close()
    conn.close()

    if not ids_usuario:
        raise RuntimeError("Tabela usuario está vazia — rode o dataload de usuario antes.")

    return ids_usuario


def gerar_localizacao_usuario(ids_usuario, n=500):
    linhas = []
    candidatos = ids_usuario.copy()
    random.shuffle(candidatos)

    for i in range(min(n, len(candidatos))):
        id_usuario = candidatos[i]
        roll = random.random()

        if roll < 0.82:
            cep = fake.postcode()
            estado = random.choice(UFS)
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = random.choice(["", "Apto 12", "Casa 2", "Bloco B"])
            id_usuario_out = id_usuario

        elif roll < 0.87:
            cep = fake.postcode()
            estado = random.choice(UFS)
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = ""
            id_usuario_out = str(uuid.uuid4())

        elif roll < 0.91:
            cep = fake.postcode()
            estado = random.choice(UFS)
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = ""
            id_usuario_out = "não-é-um-uuid"

        elif roll < 0.95:
            cep = fake.postcode()
            estado = random.choice(["São Paulo", "sao paulo", "SPP", ""])
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = ""
            id_usuario_out = id_usuario

        else:
            cep = random.choice(["", "12345", "cep-invalido"])
            estado = random.choice(UFS)
            bairro = fake.city_suffix()
            rua = fake.street_name()
            numero = random.randint(1, 9999)
            complemento = ""
            id_usuario_out = id_usuario

        latitude, longitude = gerar_coordenadas(estado)

        linhas.append(
            {
                "id_usuario": id_usuario_out,
                "cep": cep,
                "estado": estado,
                "bairro": bairro,
                "rua": rua,
                "numero": numero,
                "complemento": complemento,
                "latitude": latitude,
                "longitude": longitude,
            }
        )

    return linhas


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--offline", action="store_true", help="não conecta no banco, gera IDs fake")
    parser.add_argument("--n", type=int, default=500, help="quantidade de linhas a gerar")
    parser.add_argument("--saida", default="localizacao_usuario.csv", help="caminho do CSV de saída")
    args = parser.parse_args()

    ids_usuario = buscar_ids_usuario(args.offline)
    linhas = gerar_localizacao_usuario(ids_usuario, n=args.n)

    with open(args.saida, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f, fieldnames=["id_usuario", "cep", "estado", "bairro", "rua", "numero", "complemento", "latitude", "longitude"]
        )
        writer.writeheader()
        writer.writerows(linhas)

    print(f"{args.saida} gerado com {len(linhas)} linhas")