"""Verifica um dump formato custom: existe, tamanho > 0, assinatura PGDMP e
catálogo legível por `pg_restore --list`.

Uso: python ops/verify_backup.py backups/arquivo.dump
"""
import argparse
import subprocess
import sys
from pathlib import Path

from pgbin import pg_cmd


def verificar(caminho):
    p = Path(caminho)
    if not p.is_file():
        print(f"ERRO: arquivo não encontrado: {p}", file=sys.stderr)
        return 1
    tamanho = p.stat().st_size
    if tamanho == 0:
        print(f"ERRO: arquivo vazio: {p}", file=sys.stderr)
        return 1
    with p.open("rb") as f:
        if f.read(5) != b"PGDMP":
            print(f"ERRO: não é dump formato custom (-Fc): {p}", file=sys.stderr)
            return 1
    with p.open("rb") as f:
        r = subprocess.run(pg_cmd("pg_restore", "--list"), stdin=f, capture_output=True)
    if r.returncode != 0:
        print(r.stderr.decode(errors="replace"), file=sys.stderr)
        return r.returncode
    entradas = [l for l in r.stdout.decode(errors="replace").splitlines() if l and not l.startswith(";")]
    print(f"OK: {p} | {tamanho} bytes | {len(entradas)} entradas no catálogo")
    return 0


def main():
    ap = argparse.ArgumentParser(description="Verifica integridade de um dump pg_dump -Fc.")
    ap.add_argument("dump", help="caminho do arquivo .dump")
    return verificar(ap.parse_args().dump)


if __name__ == "__main__":
    sys.exit(main())
