"""Checagem somente-leitura do banco configurado no .env, via
src.database.connection.get_connection (mesma conexão do setup_data).

Mostra database, versão, TLS, presença das tabelas operacionais e o resumo
de log_rpa_execucao. Nunca imprime senha/DSN. Exit 0 = ok, 1 = falha.

Uso: python ops/check_db.py
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.database.connection import get_connection  # noqa: E402

TABELAS = ("usuario", "sessao_acesso", "log_rpa_execucao")


def main():
    argparse.ArgumentParser(description="Checa conexão e tabelas operacionais (somente leitura).").parse_args()
    try:
        conn = get_connection()
    except Exception as e:
        print(f"FALHA: conexão recusada ({type(e).__name__})", file=sys.stderr)
        return 1

    ok = True
    try:
        conn.set_session(readonly=True)
        cur = conn.cursor()
        cur.execute("SELECT current_database(), current_setting('server_version')")
        db, versao = cur.fetchone()
        cur.execute("SELECT ssl, version FROM pg_stat_ssl WHERE pid = pg_backend_pid()")
        ssl, tls = cur.fetchone()
        print(f"database={db} | server={versao} | ssl={ssl} {tls or ''}")

        for t in TABELAS:
            cur.execute("SELECT to_regclass(%s) IS NOT NULL", (t,))
            existe = cur.fetchone()[0]
            ok &= existe
            print(f"[{'OK' if existe else 'FALHA'}] tabela {t}")

        if ok:
            cur.execute("""SELECT nome_processo, status, COUNT(*), MAX(iniciado_em)
                           FROM log_rpa_execucao GROUP BY 1, 2 ORDER BY 1, 2""")
            linhas = cur.fetchall()
            print("log_rpa_execucao:", "vazia" if not linhas else "")
            for proc, status, n, ultima in linhas:
                print(f"  {proc} | {status} | {n} execução(ões) | última {ultima}")
    except Exception as e:
        print(f"FALHA: {type(e).__name__}: {e}", file=sys.stderr)
        ok = False
    finally:
        conn.close()
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
