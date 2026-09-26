"""
Quimia — Plano de execução do setup_data.py (só leitura).

Lê o texto de src/setup_data.py e src/database/utils/staging/loader.py (sem
importar nenhum dos dois: o loader abre conexão com o banco ao ser importado)
e reconstrói a ordem real em que o setup cria e carrega o banco. Depois cruza
essa ordem com os arquivos e objetos do catálogo para apontar problemas.
"""

import re
from pathlib import Path

SETUP = "src/setup_data.py"
LOADER = "src/database/utils/staging/loader.py"
STAGING = "src/database/sql/data_load/staging"

# Objetos que o banco precisa que já existam no momento do CREATE. Corpo de
# function/procedure plpgsql não é validado na criação, e as FKs das tabelas
# são adicionadas no foreign_keys.sql, então esses tipos não entram na checagem.
TIPOS_VALIDADOS_NA_CRIACAO = {"view", "trigger", "indice"}


def _mapa_loader(texto: str) -> dict[str, dict]:
    mapa = {}
    for m in re.finditer(r'"(\w+)"\s*:\s*\{(.*?)\}', texto, re.S):
        corpo = m.group(2)
        stg = re.search(r'"stg_table"\s*:\s*"(\w+)"', corpo)
        validate = re.search(r'"validate_sql"\s*:\s*BASE_DIR\s*/\s*"(\w+)"\s*/\s*"([\w.]+)"', corpo)
        migrate = re.search(r'"migrate_sql"\s*:\s*BASE_DIR\s*/\s*"(\w+)"\s*/\s*"([\w.]+)"', corpo)
        if stg:
            mapa[m.group(1)] = {
                "stg": stg.group(1),
                "validate": f"{STAGING}/{validate.group(1)}/{validate.group(2)}" if validate else None,
                "migrate": f"{STAGING}/{migrate.group(1)}/{migrate.group(2)}" if migrate else None,
            }
    return mapa


def _csv_da_variavel(texto: str, variavel: str, antes_de: int) -> str | None:
    """`csv_x = salvar_csv("caminho", ...)` mais próximo antes da chamada."""
    achados = [m for m in re.finditer(rf'\b{re.escape(variavel)}\s*=\s*salvar_csv\(\s*"([^"]+)"', texto)
               if m.start() < antes_de]
    return achados[-1].group(1) if achados else None


def analisar_setup(raiz: Path, arquivos: dict[str, dict], objetos: dict[str, dict]) -> dict:
    caminho_setup = raiz / SETUP
    if not caminho_setup.exists():
        return {"disponivel": False, "motivo": f"{SETUP} não encontrado."}
    texto = caminho_setup.read_text(encoding="utf-8")
    loader = _mapa_loader((raiz / LOADER).read_text(encoding="utf-8")) if (raiz / LOADER).exists() else {}

    eventos = []
    for m in re.finditer(r"executar_scripts\(\s*\[(.*?)\]\s*\)", texto, re.S):
        eventos.append((m.start(), "scripts", re.findall(r'"([^"]+\.sql)"', m.group(1))))
    for m in re.finditer(r'rodar_pipeline\(\s*"(\w+)"\s*,\s*([^)]+?)\s*\)', texto):
        eventos.append((m.start(), "carga", (m.group(1), m.group(2).strip(), m.start())))
    eventos.sort(key=lambda e: e[0])

    fases, ordem, verificacoes = [], [], []
    atual = None
    for _, tipo, conteudo in eventos:
        if tipo == "scripts":
            atual = {"tipo": "scripts", "passos": []}
            fases.append(atual)
            for caminho in conteudo:
                arquivo = arquivos.get(caminho)
                atual["passos"].append({
                    "arquivo": caminho, "existe": arquivo is not None,
                    "grupo": arquivo["grupo"] if arquivo else None,
                    "objetos": arquivo["objetos"] if arquivo else [],
                })
                ordem.append(caminho)
            atual = None
        else:
            tabela, argumento, posicao = conteudo
            if atual is None:
                atual = {"tipo": "carga", "passos": []}
                fases.append(atual)
            if argumento.startswith('"'):
                csv, gerado = argumento.strip('"'), False
            else:
                csv, gerado = _csv_da_variavel(texto, argumento, posicao), True
            etapa = loader.get(tabela, {})
            passo = {"tabela": tabela, "csv": csv, "csv_gerado": gerado, "stg": etapa.get("stg"),
                     "validate": etapa.get("validate"), "migrate": etapa.get("migrate")}
            atual["passos"].append(passo)
            for chave in ("validate", "migrate"):
                if passo[chave]:
                    ordem.append(passo[chave])
            if not etapa:
                verificacoes.append({"nivel": "erro", "texto": f"rodar_pipeline(\"{tabela}\") não tem entrada no TABELAS do loader.py."})
            for chave in ("validate", "migrate"):
                if etapa.get(chave) and etapa[chave] not in arquivos:
                    verificacoes.append({"nivel": "erro", "texto": f"{chave} de {tabela} aponta para {etapa[chave]}, que não existe."})

    executados = set(ordem)
    for caminho in ordem:
        if caminho.endswith(".sql") and caminho not in arquivos:
            verificacoes.append({"nivel": "erro", "texto": f"O setup executa {caminho}, mas o arquivo não existe."})

    # Arquivos do repositório que o setup nunca executa.
    for caminho, arquivo in sorted(arquivos.items()):
        if caminho in executados:
            continue
        criados = [n for n in arquivo["objetos"] if n in objetos]
        detalhe = f" e cria {', '.join(criados)}, que não existe num banco recriado pelo setup" if criados else ""
        verificacoes.append({"nivel": "aviso", "arquivo": caminho,
                             "texto": f"{caminho} não é executado pelo setup_data.py{detalhe}."})

    # Ordem: views, triggers e índices precisam do que usam já criado antes.
    posicao = {}
    for i, caminho in enumerate(ordem):
        for nome in (arquivos.get(caminho) or {}).get("objetos", []):
            posicao.setdefault(nome, i)
    for nome, i in sorted(posicao.items(), key=lambda x: x[1]):
        obj = objetos.get(nome)
        if not obj or obj["tipo"] not in TIPOS_VALIDADOS_NA_CRIACAO:
            continue
        for dep in obj["dependencias"]:
            if dep in posicao and posicao[dep] > i:
                verificacoes.append({"nivel": "erro", "arquivo": obj["arquivo"],
                                     "texto": f"{nome} usa {dep}, mas {dep} só é criado depois ({arquivos_de(dep, objetos)})."})
            elif dep not in posicao:
                verificacoes.append({"nivel": "erro", "arquivo": obj["arquivo"],
                                     "texto": f"{nome} usa {dep}, que o setup nunca cria."})

    passos_scripts = sum(len(f["passos"]) for f in fases if f["tipo"] == "scripts")
    passos_carga = sum(len(f["passos"]) for f in fases if f["tipo"] == "carga")
    return {
        "disponivel": True, "arquivo": SETUP, "comando": "python -m src.setup_data",
        "fases": fases, "total_scripts": passos_scripts, "total_cargas": passos_carga,
        "verificacoes": verificacoes,
    }


def arquivos_de(nome: str, objetos: dict[str, dict]) -> str:
    obj = objetos.get(nome)
    return obj["arquivo"] if obj else "?"
