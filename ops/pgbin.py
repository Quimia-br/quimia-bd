"""Monta a linha de comando de pg_dump/pg_restore.

Usa o binário nativo se estiver no PATH; senão roda a imagem Docker
PG_TOOLS_IMAGE (padrão postgres:18, mesma major da Aiven). Em modo Docker o
arquivo de dump trafega por stdin/stdout e as credenciais são repassadas por
nome (-e PGPASSWORD), sem aparecer na linha de comando.
"""
import os
import shutil

PG_IMAGE = os.getenv("PG_TOOLS_IMAGE", "postgres:18")
PG_ENV = ("PGHOST", "PGPORT", "PGUSER", "PGPASSWORD", "PGDATABASE", "PGSSLMODE")


def usa_docker(tool):
    return shutil.which(tool) is None


def pg_cmd(tool, *args):
    if not usa_docker(tool):
        return [tool, *args]
    env = [x for nome in PG_ENV for x in ("-e", nome)]
    return ["docker", "run", "--rm", "-i", *env, PG_IMAGE, tool, *args]


def host_visto_pela_ferramenta(tool, host):
    # dentro do container, "localhost" é o próprio container, não o Windows
    if usa_docker(tool) and host in ("localhost", "127.0.0.1"):
        return "host.docker.internal"
    return host
