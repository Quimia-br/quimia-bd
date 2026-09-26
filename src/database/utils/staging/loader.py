"""
Quimia — Loader genérico de staging (padrão ELT — staging COMUM, não persistente)

Faz as 4 etapas repetíveis do pipeline:
    1. TRUNCATE -> limpa a stg_* antes de cada carga (staging comum,
                             não acumula histórico entre execuções — decisão
                             do roadmap de execução, ver contexto do projeto)
    2. COPY do CSV bruto -> tabela stg_*
    3. VALIDATE -> roda o .sql de validação, marcando ok/rejeitado
    4. MIGRATE -> roda o .sql de migração, só do que ficou 'ok'

O DDL (CREATE TABLE stg_*) continua rodando uma vez só, fora do fluxo de
carga (sql/data_load/staging/ddl/*.sql) — o TRUNCATE aqui não recria a
tabela, só esvazia o conteúdo antes de cada novo lote.

Uso:
    python loader.py --tabela fds --csv fds.csv

    # ou chamando as funções direto, ex. dentro de um notebook de teste:
    from loader import rodar_pipeline
    rodar_pipeline("fds", "sql/data_load/mock/fds.csv")

Requer variável de ambiente DATABASE_URL (ou ajuste get_connection()).
"""

import argparse
import csv
import io
import os
import uuid
from pathlib import Path

import psycopg2
from src.database.connection import get_connection


BASE_DIR = Path(__file__).resolve().parent.parent.parent / "sql" / "data_load" / "staging"


TABELAS = {
    "usuario": {
    "stg_table": "stg_usuario",
    "colunas": [
        "nome_raw", "email_raw", "data_nasc_raw", "foto_url_raw",
        "senha_raw", "nivel_acesso_raw", "ultima_sessao_raw",
        ],
    "validate_sql": BASE_DIR / "validate" / "validate_usuario.sql",
    "migrate_sql": BASE_DIR / "migrate" / "migrate_usuario_empresa.sql",
    },  
    "empresa": {
        "stg_table": "stg_empresa",
        "colunas": ["nome_raw", "email_raw", "cnpj_raw", "ativo_raw", "senha_raw", "foto_url_raw"],
        "validate_sql": BASE_DIR / "validate" / "validate_empresa.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_usuario_empresa.sql",
    },
    "fds": {
        "stg_table": "stg_fds",
        "colunas": ["id_produto_raw", "versao_raw", "data_atualizacao_raw", "fonte_url_raw", "raw_json_raw"],
        "validate_sql": BASE_DIR / "validate" / "validate_fds.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_fds.sql",
    },
    "localizacao_usuario": {
        "stg_table": "stg_localizacao_usuario",
        "colunas": [
            "id_usuario_raw", "cep_raw", "estado_raw", "bairro_raw",
            "rua_raw", "numero_raw", "complemento_raw",
        ],
        "validate_sql": BASE_DIR / "validate" / "validate_localizacao_usuario.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_localizacao_usuario.sql",
    },
    "ponto_parceiro": {
        "stg_table": "stg_ponto_parceiro",
        "colunas": [
            "id_empresa_raw", "nome_raw", "cep_raw", "estado_raw", "bairro_raw",
            "rua_raw", "numero_raw", "complemento_raw", "tipo_raw", "ativo_raw",
        ],
        "validate_sql": BASE_DIR / "validate" / "validate_ponto_parceiro.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_ponto_parceiro.sql",
    },
    "marca":{
        "stg_table":"stg_marca",
        "colunas":[
            "nome_raw"
        ],
        "validate_sql": BASE_DIR / "validate" / "validate_marca.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_marca.sql"
    },
    "classe_quimica":{
        "stg_table":"stg_classe_quimica",
        "colunas":[
            "nome_raw", "descricao_raw"
        ],
        "validate_sql": BASE_DIR / "validate" / "validate_classe_quimica.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_classe_quimica.sql"
    },
    "substancia":{
        "stg_table":"stg_substancia",
        "colunas":[
            "nome_canonico_raw", "cas_numero_raw",
            "descricao_raw", 
        ],
        "validate_sql": BASE_DIR / "validate" / "validate_substancia.sql",
        "migrate_sql": BASE_DIR / "migrate" / "migrate_substancia.sql"
    }, "estante": {
    "stg_table": "stg_estante",
    "colunas": ["id_usuario_raw", "nome_raw", "ambiente_raw"],
    "validate_sql": BASE_DIR / "validate" / "validate_estante.sql",
    "migrate_sql": BASE_DIR / "migrate" / "migrate_estante.sql",
    },
    "substancia_classe_quimica": {
    "stg_table": "stg_substancia_classe_quimica",
    "colunas": ["id_substancia_raw", "id_classe_quimica_raw"],
    "validate_sql": BASE_DIR / "validate" / "validate_substancia_classe_quimica.sql",
    "migrate_sql": BASE_DIR / "migrate" / "migrate_substancia_classe_quimica.sql",
    },
    "substancia_sinonimo": {
        "stg_table": "stg_substancia_sinonimo",
    "colunas": ["id_substancia_raw", "sinonimo_raw"],
    "validate_sql": BASE_DIR / "validate" / "validate_substancia_sinonimo.sql",
    "migrate_sql": BASE_DIR / "migrate" / "migrate_substancia_sinonimo.sql",
    }, 
    "produto": {
    "stg_table": "stg_produto",
    "colunas": [
        "nome_raw", "id_marca_raw", "descricao_raw",
        "tipo_produto_raw", "cod_barras_raw", "foto_url_raw",
    ],
    "validate_sql": BASE_DIR / "validate" / "validate_produto.sql",
    "migrate_sql": BASE_DIR / "migrate" / "migrate_produto.sql",
    },
    "historico_recomendacao": {
    "stg_table": "stg_historico_recomendacao",
    "colunas": ["id_produto_raw", "id_usuario_raw", "resultado_raw", "dosagem_sugerida_raw"],
    "validate_sql": BASE_DIR / "validate" / "validate_historico_recomendacao.sql",
    "migrate_sql": BASE_DIR / "migrate" / "migrate_historico_recomendacao.sql",
    },
    "incompatibilidade_regra": {
    "stg_table": "stg_incompatibilidade_regra",
    "colunas": [
        "id_substancia_a_raw", "id_classe_a_raw",
        "id_substancia_b_raw", "id_classe_b_raw",
        "severidade_raw", "descricao_risco_raw", "fonte_raw", "ativo_raw",
    ],
    "validate_sql": BASE_DIR / "validate" / "validate_incompatibilidade_regra.sql",
    "migrate_sql": BASE_DIR / "migrate" / "migrate_incompatibilidade_regra.sql",
    },
}   

conn = get_connection()


def truncar_staging(conn, tabela: str): 
    """
    Esvazia a stg_* antes de cada carga. Não recria a tabela (isso é
    responsabilidade do DDL, rodado uma vez só) — só garante que cada
    execução do pipeline começa com a staging vazia, sem acumular
    lotes antigos.
    """
    stg_table = TABELAS[tabela]["stg_table"]
    cur = conn.cursor()
    cur.execute(f"TRUNCATE {stg_table} RESTART IDENTITY")
    conn.commit()
    cur.close()



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



def rodar_pipeline(tabela: str, caminho_csv: str) -> uuid.UUID:
    if tabela not in TABELAS:
        raise ValueError(f"Tabela '{tabela}' não configurada em TABELAS. Opções: {list(TABELAS)}")

    config = TABELAS[tabela]
    id_batch = uuid.uuid4()
    conn = get_connection()

    try:
        print(f"[{tabela}] limpando staging ({config['stg_table']})...")
        print("DEBUG chaves:", list(config.keys()))
        truncar_staging(conn, tabela)

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


# CLI

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Loader genérico de staging (Quimia)")
    parser.add_argument("--tabela", required=True, choices=list(TABELAS.keys()))
    parser.add_argument("--csv", required=True, help="Caminho do CSV de origem")
    args = parser.parse_args()

    rodar_pipeline(args.tabela, args.csv)