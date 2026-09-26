"""
Quimia — Gerador do Catálogo de Dados visual.

Varre os .sql do repositório, consolida os objetos com seus COMMENT ON e a
classificação do seed (domínio, nível de acesso, LGPD, regras) e grava os
dados do site estático em docs/catalog/, que abre direto no navegador.

O site (HTML, CSS, JS e ícones) é editado direto em docs/catalog/. Este
gerador só reescreve os arquivos gerados: data.js, icons.js e diffs/.

Uso:
    python -m src.catalog_site.generate_catalog
"""

import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from src.catalog_site.git_info import alteracoes_locais, historico
from src.catalog_site.sql_parser import aplicar_classificacao, analisar_arquivo, analisar_carga
from src.catalog_site.execution_plan import analisar_setup

RAIZ = Path(__file__).resolve().parents[2]
SQL = RAIZ / "src" / "database" / "sql"
SITE = RAIZ / "docs" / "catalog"
SEED_CLASSIFICACAO = "seed_catalogo_classificacao.sql"

# (pasta, categoria do parser, grupo na página Scripts). A categoria vem da
# pasta, não do nome do arquivo. Os scripts de carga (staging e seeds) viram
# arquivos do grupo "dataload", mas não geram objetos: stg_* não é dado oficial.
PASTAS = [
    (SQL / "ddl" / "tables", "tabela", "criacao"),
    (SQL / "ddl" / "constraints", "tabela", "criacao"),
    (SQL / "ddl" / "comments", "comentario", "criacao"),
    (SQL / "logs", "log", "log"),
    (SQL / "routines" / "functions", "funcao", "funcao"),
    (SQL / "routines" / "procedures", "procedure", "procedure"),
    (SQL / "routines" / "triggers", "trigger", "trigger"),
    (SQL / "indexes", "indice", "indice"),
    (SQL / "data_mart", "view", "view"),
    (SQL / "data_load" / "seeds", None, "dataload"),
    (SQL / "data_load" / "staging" / "ddl_staging", None, "dataload"),
    (SQL / "data_load" / "staging" / "validate", None, "dataload"),
    (SQL / "data_load" / "staging" / "migrate", None, "dataload"),
]

TIPOS_RELACAO = ("tabela", "log", "view")
TIPOS_ROTINA = ("funcao", "procedure")


def listar_arquivos():
    for pasta, categoria, grupo in PASTAS:
        for arquivo in sorted(pasta.rglob("*.sql")):
            yield arquivo, categoria, grupo


def datas_git():
    """Data do último commit de cada arquivo .sql (caminho relativo -> ISO)."""
    try:
        saida = subprocess.run(
            ["git", "log", "--format=\x1e%cI", "--name-only", "--", "src/database/sql"],
            cwd=RAIZ, capture_output=True, text=True, check=True, encoding="utf-8",
        ).stdout
    except (OSError, subprocess.CalledProcessError):
        return {}
    datas = {}
    for bloco in saida.split("\x1e")[1:]:
        linhas = [l.strip() for l in bloco.strip().splitlines() if l.strip()]
        if not linhas:
            continue
        for caminho in linhas[1:]:
            datas.setdefault(caminho, linhas[0])  # o log vem do mais novo para o mais antigo
    return datas


def commit_atual():
    try:
        saida = subprocess.run(
            ["git", "log", "-1", "--format=%h|%cI"], cwd=RAIZ, capture_output=True, text=True, check=True
        ).stdout.strip()
        curto, data = saida.split("|")
        return {"hash": curto, "data": data}
    except (OSError, subprocess.CalledProcessError, ValueError):
        return None


def construir_catalogo():
    objetos, fks, comentarios, classificacao, avisos, arquivos = {}, [], [], [], [], []
    datas = datas_git()

    for arquivo, categoria, grupo in listar_arquivos():
        relativo = arquivo.relative_to(RAIZ).as_posix()
        conteudo = arquivo.read_text(encoding="utf-8")
        versionado = relativo in datas
        registro = {
            "caminho": relativo, "nome": arquivo.name, "grupo": grupo,
            "bytes": len(conteudo.encode("utf-8")), "linhas": conteudo.count("\n") + 1,
            "alterado_em": datas.get(relativo) or datetime.fromtimestamp(
                arquivo.stat().st_mtime, timezone.utc).isoformat(timespec="seconds"),
            "versionado": versionado, "objetos": [], "comentarios": 0, "fks": 0, "carga": None,
            "conteudo": conteudo,
        }
        arquivos.append(registro)

        if categoria is None:
            registro["carga"] = analisar_carga(conteudo)
            if arquivo.name != SEED_CLASSIFICACAO:
                continue
            categoria = "seed"

        resultado = analisar_arquivo(relativo, conteudo, categoria)
        registro["objetos"] = [o["nome"] for o in resultado["objetos"]]
        registro["comentarios"] = len(resultado["comentarios"])
        registro["fks"] = len(resultado["fks"])
        for obj in resultado["objetos"]:
            if obj["nome"] in objetos:
                avisos.append(f"{obj['nome']} está definido em {objetos[obj['nome']]['arquivo']} e em {relativo}; "
                              f"vale o último.")
            objetos[obj["nome"]] = obj
        fks += resultado["fks"]
        comentarios += resultado["comentarios"]
        classificacao += resultado.get("classificacao", [])
        avisos += resultado["avisos"]

    for fk in fks:
        tabela = objetos.get(fk["tabela"])
        if not tabela or len(fk["colunas"]) != 1:
            avisos.append(f"FK {fk['nome']} em {fk['arquivo']} aponta para tabela/coluna desconhecida.")
            continue
        coluna = next((c for c in tabela["colunas"] if c["nome"] == fk["colunas"][0]), None)
        if not coluna:
            avisos.append(f"FK {fk['nome']}: coluna {fk['tabela']}.{fk['colunas'][0]} não existe.")
            continue
        coluna["fk"] = {**fk["referencia"], "nome": fk["nome"]}

    aplicar_comentarios(objetos, comentarios, avisos)
    avisos += aplicar_classificacao(classificacao, objetos)
    relacionamentos = calcular_dependencias(objetos, avisos)
    avisos += verificar_cobertura(objetos)
    plano = analisar_setup(RAIZ, {a["caminho"]: a for a in arquivos}, objetos)

    lista = sorted(objetos.values(), key=lambda o: (o["tipo"], o["nome"]))
    for obj in lista:
        for chave in [k for k in obj if k.startswith("_")]:
            del obj[chave]

    tipos = ("tabela", "log", "view", "funcao", "procedure", "trigger", "indice")
    return {
        "projeto": {"nome": "Quimia", "titulo": "Catálogo de Dados",
                    "descricao": "Documentação navegável do banco PostgreSQL do Quimia"},
        "gerado_em": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "commit": commit_atual(),
        "contagens": {**{t: sum(1 for o in lista if o["tipo"] == t) for t in tipos},
                      "dataload": sum(1 for a in arquivos if a["grupo"] == "dataload")},
        "objetos": lista,
        "arquivos": arquivos,
        "relacionamentos": relacionamentos,
        "avisos": avisos,
        "plano": plano,
    }


def aplicar_comentarios(objetos, comentarios, avisos):
    ja_vistos = {}
    for c in comentarios:
        chave = (c["tipo"], c["alvo"])
        if chave in ja_vistos:
            avisos.append(f"COMMENT ON {c['tipo']} {c['alvo']} aparece em {ja_vistos[chave]} e em {c['arquivo']}; "
                          f"vale o último.")
        ja_vistos[chave] = c["arquivo"]

        if c["tipo"] == "COLUMN":
            tabela, _, coluna = c["alvo"].rpartition(".")
            obj = objetos.get(tabela)
            if not obj or obj["tipo"] not in TIPOS_RELACAO:
                avisos.append(f"COMMENT ON COLUMN {c['alvo']} ({c['arquivo']}): objeto não encontrado nos .sql.")
                continue
            col = next((x for x in obj["colunas"] if x["nome"] == coluna), None)
            if col is None:
                if obj["tipo"] != "view":
                    avisos.append(f"COMMENT ON COLUMN {c['alvo']}: a coluna não existe no CREATE TABLE.")
                    continue
                # Views não têm colunas declaradas: a lista vem dos comentários.
                col = {"nome": coluna, "tipo": None, "descricao": None}
                obj["colunas"].append(col)
            col["descricao"] = c["texto"]
            continue

        obj = objetos.get(c["alvo"])
        if not obj:
            avisos.append(f"COMMENT ON {c['tipo']} {c['alvo']} ({c['arquivo']}): objeto não encontrado nos .sql.")
            continue
        obj["descricao"] = c["texto"]


def calcular_dependencias(objetos, avisos):
    relacoes = {n for n, o in objetos.items() if o["tipo"] in TIPOS_RELACAO}
    rotinas = {n for n, o in objetos.items() if o["tipo"] in TIPOS_ROTINA}

    for obj in objetos.values():
        deps = set()
        if obj["tipo"] in ("view", "funcao", "procedure"):
            deps = (obj.get("_deps", set()) & relacoes) | (obj.get("_chamadas", set()) & rotinas)
        elif obj["tipo"] == "trigger":
            deps = {obj["tabela"], obj["funcao"]}
        elif obj["tipo"] == "indice":
            deps = {obj["tabela"]}
        elif obj["tipo"] in ("tabela", "log"):
            deps = {c["fk"]["tabela"] for c in obj["colunas"] if c.get("fk")}
        deps.discard(obj["nome"])
        for d in deps - set(objetos):
            avisos.append(f"{obj['nome']} depende de {d}, que não está definido nos .sql do repositório.")
        obj["dependencias"] = sorted(deps & set(objetos))
        obj.setdefault("usado_por", [])

    for obj in objetos.values():
        for dep in obj["dependencias"]:
            objetos[dep].setdefault("usado_por", []).append(obj["nome"])
    for obj in objetos.values():
        obj["usado_por"] = sorted(set(obj["usado_por"]))

    return [
        {"de": obj["nome"], "coluna": col["nome"], "para": col["fk"]["tabela"],
         "coluna_ref": col["fk"]["colunas"][0], "on_delete": col["fk"].get("on_delete"),
         "obrigatoria": col["obrigatorio"]}
        for obj in objetos.values() if obj["tipo"] in ("tabela", "log")
        for col in obj["colunas"] if col.get("fk")
    ]


def verificar_cobertura(objetos):
    avisos = []
    for obj in objetos.values():
        if not obj.get("descricao"):
            avisos.append(f"{obj['nome']} ({obj['tipo']}) está sem COMMENT ON.")
        if obj["tipo"] in TIPOS_RELACAO and not obj.get("nivel_acesso"):
            avisos.append(f"{obj['nome']} está sem nível de acesso no seed de classificação.")
        for col in obj.get("colunas", []):
            if obj["tipo"] != "view" and not col.get("descricao"):
                avisos.append(f"Coluna {obj['nome']}.{col['nome']} está sem COMMENT ON.")
    return avisos


def _escrever_diff(nome: str, conteudo: dict):
    """Diff num .js próprio: o site só carrega (via <script>) quando o usuário abre."""
    dados = json.dumps(conteudo, ensure_ascii=False, separators=(",", ":"))
    (SITE / "diffs" / f"{nome}.js").write_text(
        f"(window.CATALOGO_DIFFS = window.CATALOGO_DIFFS || {{}})[{json.dumps(nome)}] = {dados};\n", encoding="utf-8"
    )


def gerar_site(catalogo, diffs_historico=None, diffs_alteracoes=None):
    """Reescreve só os arquivos gerados do site; o resto de docs/catalog/ é editado à mão."""
    # Diffs antigos saem para não sobrar commit que deixou o escopo. Só os
    # arquivos: no Windows o OneDrive segura pastas e o rmdir dá "Acesso negado".
    (SITE / "diffs").mkdir(parents=True, exist_ok=True)
    for antigo in (SITE / "diffs").glob("*.js"):
        antigo.unlink()
    # Dados e ícones vão em .js (e não .json/.svg buscados via fetch) para o
    # site abrir via file:// sem servidor. Os ícones ficam inline para herdar
    # a cor do tema; os SVGs do logo são usados como <img> e não entram aqui.
    # Compacto de propósito: é dado gerado, não código (indentado passava de 8 mil linhas).
    dados = json.dumps(catalogo, ensure_ascii=False, separators=(",", ":"))
    (SITE / "data.js").write_text(
        "/* Gerado por src/catalog_site/generate_catalog.py. Não edite: rode o gerador de novo. */\n"
        f"window.CATALOGO = {dados};\n", encoding="utf-8"
    )
    icones = {
        svg.stem: svg.read_text(encoding="utf-8").strip()
        for svg in sorted((SITE / "icons").glob("*.svg"))
        if not svg.stem.startswith("logo")
    }
    (SITE / "icons.js").write_text(
        "/* Gerado a partir de docs/catalog/icons/*.svg. Não edite: rode o gerador de novo. */\n"
        f"window.ICONES = {json.dumps(icones, ensure_ascii=False)};\n", encoding="utf-8"
    )
    for curto, diff in (diffs_historico or {}).items():
        _escrever_diff(f"commit-{curto}", diff)
    if diffs_alteracoes:
        _escrever_diff("changes", diffs_alteracoes)


def main():
    catalogo = construir_catalogo()
    catalogo["historico"], diffs_historico = historico(RAIZ)
    catalogo["alteracoes"], diffs_alteracoes = alteracoes_locais(RAIZ)
    gerar_site(catalogo, diffs_historico, diffs_alteracoes)
    contagens = ", ".join(f"{v} {k}" for k, v in catalogo["contagens"].items())
    print(f"Catálogo gerado em {SITE.relative_to(RAIZ).as_posix()}/index.html")
    print(f"Objetos: {contagens}")
    print(f"Relacionamentos (FK): {len(catalogo['relacionamentos'])}")
    print(f"Avisos: {len(catalogo['avisos'])}")
    for aviso in catalogo["avisos"]:
        print(f"  - {aviso}")
    plano = catalogo["plano"]
    if plano.get("disponivel"):
        print(f"Plano de execução: {plano['total_scripts']} scripts, {plano['total_cargas']} cargas, "
              f"{len(plano['verificacoes'])} verificação(ões)")
        for v in plano["verificacoes"]:
            print(f"  - [{v['nivel']}] {v['texto']}")
    hist, alt = catalogo["historico"], catalogo["alteracoes"]
    print(f"Histórico: {len(hist['commits'])} commits" if hist["disponivel"] else f"Histórico: {hist['motivo']}")
    print(f"Alterações locais: {len(alt['arquivos'])} arquivos" if alt["disponivel"] else f"Alterações: {alt['motivo']}")


if __name__ == "__main__":
    main()
