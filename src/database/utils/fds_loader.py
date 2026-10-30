"""
Quimia — Carga das FDS curadas: liga cada JSON do parser (seeds/fds/<arquivo>.json)
ao produto indicado em seeds/fds/fds_produto.csv. O INSERT em fds dispara
trg_processar_fds_raw_json, que resolve compostos, incompatibilidades etc.

Arquivo ausente é pulado com aviso: os JSONs vêm de FDS reais e entram no repo
só quando o responsável decidir versioná-los.
"""

import csv
import json
from pathlib import Path

from psycopg2.extras import Json

FDS_DIR = (
    Path(__file__).resolve().parent.parent
    / "sql" / "data_load" / "seeds" / "fds"
)


def carregar_fds_curadas(conn):
    cur = conn.cursor()
    carregadas = 0
    with open(FDS_DIR / "fds_produto.csv", newline="", encoding="utf-8-sig") as f:
        for linha in csv.DictReader(f):
            arquivo = FDS_DIR / linha["arquivo"].strip()
            nome = linha["nome_produto"].strip()
            if not arquivo.exists():
                print(f"[aviso] FDS '{arquivo.name}' não encontrada — produto '{nome}' fica sem FDS")
                continue
            cur.execute("SELECT id FROM produto WHERE nome = %s ORDER BY id LIMIT 1", (nome,))
            produto = cur.fetchone()
            if not produto:
                print(f"[aviso] produto '{nome}' não existe — FDS '{arquivo.name}' pulada")
                continue
            with open(arquivo, encoding="utf-8") as j:
                cur.execute(
                    "INSERT INTO fds (id_produto, versao, raw_json) VALUES (%s, %s, %s)",
                    (produto[0], "v1", Json(json.load(j))),
                )
            carregadas += 1
    conn.commit()
    cur.close()
    print(f"[fds] {carregadas} FDS vinculadas a produtos")
    return carregadas
