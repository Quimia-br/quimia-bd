"""
Quimia — Histórico e alterações locais dos scripts SQL, lidos do git.

Só leitura: usa apenas `git log`, `git show`, `git status` e `git diff`.
O escopo é fixo em src/database/sql/**.sql; commits e arquivos fora dele
não entram. Sem git (projeto baixado como ZIP), devolve disponivel=False e o
restante do catálogo é gerado normalmente.
"""

import subprocess
from pathlib import Path

ESCOPO = "src/database/sql"
PATHSPEC = f":(glob){ESCOPO}/**/*.sql"
MAX_LINHAS_DIFF = 3000

STATUS_LOG = {"A": "adicionado", "M": "modificado", "D": "removido", "R": "renomeado", "C": "copiado", "T": "modificado"}
STATUS_LOCAL = {"M": "modificado", "A": "adicionado", "D": "removido", "R": "renomeado", "?": "nao_versionado"}


def _git(raiz: Path, *args: str) -> str:
    return subprocess.run(
        ["git", "-c", "core.quotepath=false", *args],
        cwd=raiz, capture_output=True, text=True, check=True, encoding="utf-8", errors="replace",
    ).stdout


def git_disponivel(raiz: Path) -> bool:
    try:
        return _git(raiz, "rev-parse", "--is-inside-work-tree").strip() == "true"
    except (OSError, subprocess.CalledProcessError):
        return False


def analisar_diff(patch: str, max_linhas: int = MAX_LINHAS_DIFF) -> dict[str, dict]:
    """Diff unificado -> {caminho: {linhas: [[tipo, texto]], adicoes, remocoes, truncado, binario}}."""
    blocos, atual, no_trecho = {}, None, False
    for bruta in patch.split("\n"):
        linha = bruta.rstrip("\r")
        if linha.startswith("diff --git "):
            atual = {"linhas": [], "adicoes": 0, "remocoes": 0, "truncado": False, "binario": False, "_caminho": None}
            no_trecho = False
            partes = linha.split(" b/", 1)
            if len(partes) == 2:
                atual["_caminho"] = partes[1]
                blocos[partes[1]] = atual
            continue
        if atual is None:
            continue
        # "--- " e "+++ " só são cabeçalho antes do primeiro @@: dentro do trecho,
        # "--- x" é a remoção de um comentário SQL "-- x".
        if not no_trecho and linha.startswith("+++ "):
            destino = linha[4:].strip()
            if destino.startswith("b/") and destino[2:] != atual["_caminho"]:
                blocos.pop(atual["_caminho"], None)
                atual["_caminho"] = destino[2:]
                blocos[destino[2:]] = atual
            continue
        if not no_trecho and linha.startswith("--- "):
            continue
        if not no_trecho and (linha.startswith("Binary files") or linha.startswith("GIT binary patch")):
            atual["binario"] = True
            continue
        if linha.startswith("@@"):
            no_trecho = True
            tipo, texto = "meta", linha
        elif not no_trecho or linha.startswith("\\"):
            continue
        elif linha.startswith("+"):
            tipo, texto = "add", linha[1:]
            atual["adicoes"] += 1
        elif linha.startswith("-"):
            tipo, texto = "del", linha[1:]
            atual["remocoes"] += 1
        else:
            tipo, texto = "igual", linha[1:]
        if len(atual["linhas"]) >= max_linhas:
            atual["truncado"] = True
            continue
        atual["linhas"].append([tipo, texto])
    for bloco in blocos.values():
        bloco.pop("_caminho", None)
    return blocos


def historico(raiz: Path, max_commits: int = 200) -> tuple[dict, dict]:
    """
    Devolve (indice, diffs). O índice vai para data.js; os diffs de cada
    commit vão para arquivos separados, carregados só quando o commit é aberto.
    """
    if not git_disponivel(raiz):
        return {"disponivel": False, "motivo": "Este projeto não está num repositório git.", "commits": []}, {}
    try:
        _git(raiz, "rev-parse", "--verify", "HEAD")
    except subprocess.CalledProcessError:
        return {"disponivel": False, "motivo": "O repositório ainda não tem commits.", "commits": []}, {}

    separador_registro, separador_campo = "\x1e", "\x1f"
    formato = separador_registro + separador_campo.join(["%H", "%h", "%an", "%aI", "%s", "%b"]) + separador_campo
    saida = _git(raiz, "log", f"-n{max_commits}", "-M", "--name-status", f"--format={formato}", "--", PATHSPEC)

    commits, diffs = [], {}
    for registro in saida.split(separador_registro)[1:]:
        campos = registro.split(separador_campo)
        if len(campos) < 7:
            continue
        hash_completo, curto, autor, data, assunto, corpo = (c.strip() for c in campos[:6])
        arquivos = []
        for linha in campos[6].strip().splitlines():
            partes = linha.split("\t")
            if len(partes) < 2:
                continue
            letra = partes[0][:1]
            caminho = partes[2] if letra in "RC" and len(partes) > 2 else partes[1]
            arquivos.append({
                "caminho": caminho, "anterior": partes[1] if letra in "RC" and len(partes) > 2 else None,
                "status": STATUS_LOG.get(letra, "modificado"),
            })
        if not arquivos:
            continue
        patch = _git(raiz, "show", hash_completo, "--format=", "-M", "--unified=3", "--", PATHSPEC)
        blocos = analisar_diff(patch)
        for arquivo in arquivos:
            bloco = blocos.get(arquivo["caminho"]) or blocos.get(arquivo["anterior"] or "")
            arquivo["adicoes"] = bloco["adicoes"] if bloco else 0
            arquivo["remocoes"] = bloco["remocoes"] if bloco else 0
        # O e-mail do autor nunca entra no site publicado.
        commits.append({
            "hash": hash_completo, "curto": curto, "autor": autor, "data": data,
            "assunto": assunto, "corpo": corpo, "arquivos": arquivos,
            "adicoes": sum(a["adicoes"] for a in arquivos), "remocoes": sum(a["remocoes"] for a in arquivos),
        })
        diffs[curto] = {"arquivos": [{"caminho": a["caminho"], **(blocos.get(a["caminho"]) or blocos.get(a["anterior"] or "") or
                                                                  {"linhas": [], "truncado": False, "binario": False})}
                                     for a in arquivos]}

    branch = _git(raiz, "rev-parse", "--abbrev-ref", "HEAD").strip()
    atual = _git(raiz, "log", "-1", "--format=%h|%aI").strip().split("|")
    return {
        "disponivel": True, "escopo": ESCOPO, "branch": None if branch == "HEAD" else branch,
        "commit_atual": atual[0], "data_atual": atual[1], "limite": max_commits,
        "truncado": len(commits) >= max_commits, "commits": commits,
    }, diffs


def alteracoes_locais(raiz: Path) -> tuple[dict, dict]:
    """Arquivos .sql de src/database/sql diferentes do último commit, no momento da geração."""
    if not git_disponivel(raiz):
        return {"disponivel": False, "motivo": "Este projeto não está num repositório git.", "arquivos": []}, {}

    saida = _git(raiz, "status", "--porcelain=v1", "-uall", "--", PATHSPEC)
    arquivos, diffs = [], {}
    for linha in saida.splitlines():
        if len(linha) < 4:
            continue
        xy, caminho = linha[:2], linha[3:]
        anterior = None
        if " -> " in caminho:
            anterior, caminho = caminho.split(" -> ", 1)
        letra = "?" if xy == "??" else next((c for c in xy if c in "MADR"), "M")
        status = STATUS_LOCAL.get(letra, "modificado")

        if status == "nao_versionado":
            texto = (raiz / caminho).read_text(encoding="utf-8", errors="replace")
            linhas = [["add", l] for l in texto.splitlines()]
            bloco = {"linhas": linhas[:MAX_LINHAS_DIFF], "adicoes": len(linhas), "remocoes": 0,
                     "truncado": len(linhas) > MAX_LINHAS_DIFF, "binario": False}
        else:
            alvos = [caminho] + ([anterior] if anterior else [])
            blocos = analisar_diff(_git(raiz, "diff", "-M", "HEAD", "--", *alvos))
            bloco = blocos.get(caminho) or next(iter(blocos.values()), None) or \
                {"linhas": [], "adicoes": 0, "remocoes": 0, "truncado": False, "binario": False}

        arquivos.append({"caminho": caminho, "anterior": anterior, "status": status,
                         "adicoes": bloco["adicoes"], "remocoes": bloco["remocoes"]})
        diffs[caminho] = bloco

    arquivos.sort(key=lambda a: a["caminho"])
    return {"disponivel": True, "escopo": ESCOPO, "arquivos": arquivos}, {"arquivos": [
        {"caminho": a["caminho"], **diffs[a["caminho"]]} for a in arquivos]}
