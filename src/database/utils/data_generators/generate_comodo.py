"""
Gerador de dados sintéticos para a tabela comodo.

comodo depende de usuario já estar migrado (id_usuario é FK). Por isso,
igual a estante/substancia_classe_quimica/etc, o CSV deste gerador tem que
ser produzido em runtime dentro do setup_data.py, DEPOIS do pipeline de
usuario rodar — nunca como arquivo estático salvo previamente.
"""

import argparse
import csv
import random
import uuid
import argparse
import os 
import psycopg2

from src.database.connection import get_connection
from faker import Faker

fake = Faker("pt_BR")


COMODOS_COMUNS = {
    "Cozinha": "icon_cozinha",
    "Banheiro": "icon_banheiro",
    "Área de serviço": "icon_area_servico",
    "Lavanderia": "icon_lavanderia",
    "Quarto": "icon_quarto",
    "Sala": "icon_sala",
    "Garagem": "icon_garagem",
    "Despensa": "icon_despensa",
    "Varanda": "icon_varanda",
    "Escritório": "icon_escritorio",
}


def buscar_ids(conn):
    """Busca os IDs de usuario já migrados, pra usar como FK em id_usuario."""
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM usuario")
        return [row[0] for row in cur.fetchall()]


def gerar_nome_e_icone():
    """
    80% das vezes sorteia um cômodo comum (com ícone certo).
    20% simula o usuário dando um nome próprio ao cômodo (texto livre,
    sem ícone específico — cai no ícone genérico).
    """
    if random.random() < 0.8:
        nome = random.choice(list(COMODOS_COMUNS.keys()))
        icone = COMODOS_COMUNS[nome]
    else:
        nome = f"{fake.word().capitalize()} {random.choice(['do fundo', 'de cima', 'pequeno', 'novo'])}"
        icone = "icon_generico"
    return nome, icone


def gerar_linha_valida(ids_usuario):
    nome, icone = gerar_nome_e_icone()
    return {
        "id_usuario": str(random.choice(ids_usuario)),
        "nome": nome,
        "icone_comodo": icone,
    }



TIPOS_DE_RUIDO = {
    "id_usuario_invalido": 25,
    "id_usuario_inexistente": 25,
    "id_usuario_vazio": 25,
    "nome_muito_longo": 25,
}


def gerar_linha_ruido(ids_usuario):
    """Gera uma linha com algum problema, pra exercitar a validação da staging."""
    tipo = random.choices(
        list(TIPOS_DE_RUIDO.keys()),
        weights=list(TIPOS_DE_RUIDO.values()),
    )[0]

    nome, icone = gerar_nome_e_icone()
    linha = {
        "id_usuario": str(random.choice(ids_usuario)),
        "nome": nome,
        "icone_comodo": icone,
    }

    if tipo == "id_usuario_invalido":
        linha["id_usuario"] = "usuario-123-invalido"
    elif tipo == "id_usuario_inexistente":
        linha["id_usuario"] = str(uuid.uuid4())
    elif tipo == "id_usuario_vazio":
        linha["id_usuario"] = ""
    elif tipo == "nome_muito_longo":
        linha["nome"] = fake.text(max_nb_chars=250)

    return linha


def gerar_comodos(ids_usuario, quantidade=1000, proporcao_ruido=0.15):
    """
    Gera `quantidade` linhas de comodo, sendo aproximadamente `proporcao_ruido`
    delas propositalmente inválidas (pra exercitar o validate_comodo.sql).
    """
    linhas = []
    for _ in range(quantidade):
        if random.random() < proporcao_ruido:
            linhas.append(gerar_linha_ruido(ids_usuario))
        else:
            linhas.append(gerar_linha_valida(ids_usuario))
    return linhas


def salvar_csv(linhas, caminho="src/database/sql/data_load/mocks/comodo.csv"):
    with open(caminho, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f, fieldnames=["id_usuario", "nome", "icone_comodo"]
        )
        writer.writeheader()
        writer.writerows(linhas)
    return caminho

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--saida", default="src/database/sql/data_load/mocks/comodo.csv",
                         help="caminho do CSV de saída")
    parser.add_argument("--quantidade", type=int, default=1000)
    parser.add_argument("--ruido", type=float, default=0.0,
                         help="proporção de linhas propositalmente inválidas (0 a 1)")
    args = parser.parse_args()
 
    DATABASE_URL = os.environ.get("DB_URL")
    if not DATABASE_URL:
        raise RuntimeError(
            "Defina DATABASE_URL (ou QUIMIA_DB_URL) no ambiente antes de rodar "
            "este script isolado — é a string de conexão com o Postgres do Quimia."
        )
 
    conn = psycopg2.connect(DATABASE_URL)
    try:
        ids_usuario = buscar_ids(conn)
 
        if not ids_usuario:
            raise RuntimeError(
                "Nenhum usuário encontrado em `usuario`. Rode a pipeline de "
                "usuario primeiro (comodo depende dela via FK) antes de gerar "
                "comodo.csv."
            )
 
        linhas = gerar_comodos(ids_usuario, quantidade=args.quantidade, proporcao_ruido=args.ruido)
        caminho = salvar_csv(linhas, caminho=args.saida)
        print(f"{len(linhas)} linha(s) de comodo geradas em {caminho}")
    finally:
        conn.close()