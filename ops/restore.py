"""Restaura um dump -Fc em um destino EXPLÍCITO (nunca o banco do .env).

O banco de destino precisa existir. Senha do destino via variável RESTORE_PGPASSWORD.

Uso:
  python ops/restore.py backups/x.dump --host localhost --port 5433 \
      --dbname quimia_restore_test --user postgres [--clean --yes]
"""
import argparse
import os
import subprocess
import sys

from dotenv import load_dotenv

from pgbin import host_visto_pela_ferramenta, pg_cmd


def main():
    ap = argparse.ArgumentParser(description="Restaura dump pg_dump -Fc em destino explícito.")
    ap.add_argument("dump")
    ap.add_argument("--host", required=True)
    ap.add_argument("--port", required=True)
    ap.add_argument("--dbname", required=True)
    ap.add_argument("--user", required=True)
    ap.add_argument("--clean", action="store_true", help="apaga objetos existentes antes (exige --yes)")
    ap.add_argument("--yes", action="store_true", help="confirma ação destrutiva")
    a = ap.parse_args()

    load_dotenv()
    host_origem = os.getenv("DB_HOST", "")
    if a.host == host_origem or "aivencloud" in a.host.lower():
        print("ERRO: destino é o banco de origem/Aiven. Restore recusado.", file=sys.stderr)
        return 2
    if a.clean and not a.yes:
        print("ERRO: --clean apaga objetos do destino; repita com --yes.", file=sys.stderr)
        return 2
    if not os.getenv("RESTORE_PGPASSWORD"):
        print("ERRO: defina RESTORE_PGPASSWORD com a senha do destino.", file=sys.stderr)
        return 2

    env = {
        **os.environ,
        "PGHOST": host_visto_pela_ferramenta("pg_restore", a.host),
        "PGPORT": a.port,
        "PGDATABASE": a.dbname,
        "PGUSER": a.user,
        "PGPASSWORD": os.environ["RESTORE_PGPASSWORD"],
        "PGSSLMODE": os.getenv("RESTORE_PGSSLMODE", "prefer"),
    }
    # papéis/grants da Aiven não existem no destino local
    args = ["--no-owner", "--no-privileges", "-d", a.dbname]
    if a.clean:
        args += ["--clean", "--if-exists"]

    print(f"Restore de {a.dump} -> host={a.host} port={a.port} database={a.dbname}")
    with open(a.dump, "rb") as f:
        r = subprocess.run(pg_cmd("pg_restore", *args), stdin=f, env=env)
    return r.returncode


if __name__ == "__main__":
    sys.exit(main())
