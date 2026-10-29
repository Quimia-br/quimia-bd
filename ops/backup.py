"""Backup do banco configurado no .env (DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASSWORD)
com `pg_dump -Fc`, SSL obrigatório, arquivo com timestamp e verificação ao final.

Uso: python ops/backup.py [--out-dir backups]
"""
import argparse
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv

from pgbin import pg_cmd
from verify_backup import verificar

OBRIGATORIAS = ("DB_HOST", "DB_PORT", "DB_NAME", "DB_USER", "DB_PASSWORD")


def main():
    ap = argparse.ArgumentParser(description="Gera backup (pg_dump -Fc) do banco do .env.")
    ap.add_argument("--out-dir", default="backups", help="pasta de saída (padrão: backups)")
    a = ap.parse_args()

    load_dotenv()
    faltando = [v for v in OBRIGATORIAS if not os.getenv(v)]
    if faltando:
        print(f"ERRO: variáveis ausentes no ambiente: {', '.join(faltando)}", file=sys.stderr)
        return 2

    env = {
        **os.environ,
        "PGHOST": os.environ["DB_HOST"],
        "PGPORT": os.environ["DB_PORT"],
        "PGDATABASE": os.environ["DB_NAME"],
        "PGUSER": os.environ["DB_USER"],
        "PGPASSWORD": os.environ["DB_PASSWORD"],
        "PGSSLMODE": "require",  # mesmo modo de src/database/connection.py
    }

    out_dir = Path(a.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    destino = out_dir / f"{os.environ['DB_NAME']}_{datetime.now():%Y%m%d_%H%M%S}.dump"

    print(f"Backup de database={os.environ['DB_NAME']} host={os.environ['DB_HOST']} -> {destino}")
    with destino.open("xb") as f:  # "x": nunca sobrescreve
        r = subprocess.run(pg_cmd("pg_dump", "-Fc"), stdout=f, stderr=subprocess.PIPE, env=env)
    if r.returncode != 0:
        print(r.stderr.decode(errors="replace"), file=sys.stderr)
        destino.unlink(missing_ok=True)
        return r.returncode

    return verificar(destino)


if __name__ == "__main__":
    sys.exit(main())
