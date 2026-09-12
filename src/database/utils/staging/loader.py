"""
Quimia — Loader genérico de staging (padrão ELT persistente por lote)

Faz as 3 etapas repetíveis do pipeline:
    2. COPY do CSV bruto -> tabela stg_*
    3. VALIDATE          -> roda o .sql de validação, marcando ok/rejeitado
    4. MIGRATE           -> roda o .sql de migração, só do que ficou 'ok'

A etapa 1 (DDL) não entra aqui de propósito — ela roda uma vez só,
fora do fluxo de carga (sql/data_load/staging/ddl/*.sql).

Uso:
    python loader.py --tabela fds --csv fds.csv

    # ou chamando as funções direto, ex. dentro de um notebook de teste:
    from loader import rodar_pipeline
    rodar_pipeline("fds", "sql/data_load/mock/fds.csv")

Requer variável de ambiente DATABASE_URL (ou ajuste get_connection()).
"""

from src.database.connection import get_connection

import argparse
import csv
import io
import os
import uuid
import psycopg2
from pathlib import Path



BASE_DIR = Path(__file__).resolve().parent.parent.parent / "sql" / "data_load" / "staging"

# Mapeia tabela -> (arquivo de validação, arquivo de migração, colunas da stg_*)
# As colunas precisam bater 1:1 e na mesma ordem do CSV de origem.
TABELAS = {
    "usuario": {
        "stg_table": "stg_usuario",
        "colunas": ["nome_raw", "email_raw", "data_nasc_raw", "nivel_acesso_raw", "ultima_sessao_raw"],
        "validate_sql": BASE_DIR / "validate" / "validate_usuario.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_usuario_empresa.sql",
    },
    "empresa": {
        "stg_table": "stg_empresa",
        "colunas": ["nome_raw", "cnpj_raw", "ativo_raw"],
        "validate_sql": BASE_DIR / "validate" / "validate_empresa.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_usuario_empresa.sql",
    },
    "fds": {
        "stg_table": "stg_fds",
        "colunas": ["id_produto_raw", "versao_raw", "data_atualizacao_raw", "fonte_url_raw", "raw_json_raw"],
        "validate_sql": BASE_DIR / "validate" / "validate_fds.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_fds.sql",
    },
}

conn = get_connection()

# ============================================================
# ETAPA 2 — COPY do CSV bruto pra staging
# ============================================================

def copy_csv_para_staging(conn, tabela: str, caminho_csv: str, id_batch: uuid.UUID) -> int:
    """
    Lê o CSV linha a linha, injeta id_batch, e usa COPY (via cursor.copy_expert)
    para inserir tudo de uma vez na tabela stg_*. Retorna o total de linhas copiadas.
    """
    config = TABELAS[tabela]
    stg_table = config["stg_table"]
    colunas = config["colunas"]

    buffer = io.StringIO()
    writer = csv.writer(buffer, delimiter="\t")

    with open(caminho_csv, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        n_linhas = 0
        for linha in reader:
            valores = [str(id_batch)] + [linha.get(col.replace("_raw", ""), "") for col in colunas]
            # troca vazio por \N pra COPY entender como NULL
            valores = [v if v != "" else r"\N" for v in valores]
            writer.writerow(valores)
            n_linhas += 1

    buffer.seek(0)

    colunas_sql = ["id_batch"] + colunas
    cur = conn.cursor()
    cur.copy_expert(
        f"COPY {stg_table} ({', '.join(colunas_sql)}) FROM STDIN WITH (FORMAT csv, DELIMITER E'\\t', NULL '\\N')",
        buffer,
    )
    conn.commit()
    cur.close()

    return n_linhas


# ============================================================
# ETAPA 3 e 4 — rodar um .sql parametrizado por id_batch
#
# Os arquivos .sql usam ':batch_id' como placeholder (mais legível
# pra quem só olha o SQL puro). Aqui a gente troca isso pelo formato
# %(batch_id)s que o psycopg2 entende, e faz o bind de verdade —
# evita concatenar string e abrir brecha de SQL injection.
# ============================================================

def rodar_sql_parametrizado(conn, caminho_sql: Path, id_batch: uuid.UUID):
    sql_bruto = caminho_sql.read_text(encoding="utf-8")
    sql_parametrizado = sql_bruto.replace(":batch_id", "%(batch_id)s")

    cur = conn.cursor()
    cur.execute(sql_parametrizado, {"batch_id": str(id_batch)})
    conn.commit()
    cur.close()


def contar_status(conn, tabela: str, id_batch: uuid.UUID) -> dict:
    stg_table = TABELAS[tabela]["stg_table"]
    cur = conn.cursor()
    cur.execute(
        f"SELECT status, COUNT(*) FROM {stg_table} WHERE id_batch = %s GROUP BY status",
        (str(id_batch),),
    )
    resultado = dict(cur.fetchall())
    cur.close()
    return resultado


# ============================================================
# PIPELINE COMPLETO
# ============================================================

def rodar_pipeline(tabela: str, caminho_csv: str) -> uuid.UUID:
    if tabela not in TABELAS:
        raise ValueError(f"Tabela '{tabela}' não configurada em TABELAS. Opções: {list(TABELAS)}")

    config = TABELAS[tabela]
    id_batch = uuid.uuid4()
    conn = get_connection()

    try:
        print(f"[{tabela}] lote {id_batch} — iniciando COPY de {caminho_csv}")
        n_copiadas = copy_csv_para_staging(conn, tabela, caminho_csv, id_batch)
        print(f"[{tabela}] {n_copiadas} linhas copiadas para {config['stg_table']}")

        print(f"[{tabela}] rodando validação...")
        rodar_sql_parametrizado(conn, config["validate_sql"], id_batch)

        status = contar_status(conn, tabela, id_batch)
        print(f"[{tabela}] resultado da validação: {status}")

        print(f"[{tabela}] migrando linhas 'ok' para a tabela final...")
        rodar_sql_parametrizado(conn, config["migrate_sql"], id_batch)

        print(f"[{tabela}] concluído. lote: {id_batch}")
        return id_batch

    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Loader genérico de staging (Quimia)")
    parser.add_argument("--tabela", required=True, choices=list(TABELAS.keys()))
    parser.add_argument("--csv", required=True, help="Caminho do CSV de origem")
    args = parser.parse_args()

    rodar_pipeline(args.tabela, args.csv)
