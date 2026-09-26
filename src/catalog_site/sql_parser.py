"""
Quimia — Parser dos arquivos .sql para o Catálogo de Dados visual.

Lê o texto dos scripts do repositório (sem conectar no banco) e extrai
tabelas, views, functions, procedures, triggers, índices, FKs e os
COMMENT ON. É baseado em regex sobre statements já separados, então
cobre o dialeto usado neste repositório, não PostgreSQL arbitrário.
"""

import re

IDENT = r'(?:"[^"]+"|[A-Za-z_][\w$]*)(?:\.(?:"[^"]+"|[A-Za-z_][\w$]*))?'
_DOLLAR = re.compile(r"\$[A-Za-z_]*\$")


def nome(ident: str) -> str:
    """`public."Usuario"` -> `usuario`; remove schema public e aspas."""
    partes = [p.strip('"') for p in ident.strip().split(".")]
    if len(partes) == 2 and partes[0].lower() == "public":
        partes = partes[1:]
    return ".".join(partes).lower()


def espacos(texto: str) -> str:
    texto = re.sub(r"\s+", " ", texto or "").strip()
    return re.sub(r"\(\s+", "(", re.sub(r"\s+\)", ")", texto))


def separar_statements(sql: str) -> list[str]:
    """Divide por `;` de nível superior, ignorando comentários, strings e corpos $$."""
    statements, buf, i, n = [], [], 0, len(sql)
    while i < n:
        c = sql[i]
        if sql.startswith("--", i):
            fim = sql.find("\n", i)
            i = n if fim == -1 else fim
            continue
        if sql.startswith("/*", i):
            fim = sql.find("*/", i + 2)
            i = n if fim == -1 else fim + 2
            continue
        if c == "'":
            j = i + 1
            while j < n:
                if sql[j] == "'":
                    if j + 1 < n and sql[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            buf.append(sql[i:j + 1])
            i = j + 1
            continue
        if c == '"':
            fim = sql.find('"', i + 1)
            fim = n - 1 if fim == -1 else fim
            buf.append(sql[i:fim + 1])
            i = fim + 1
            continue
        if c == "$":
            m = _DOLLAR.match(sql, i)
            if m:
                fim = sql.find(m.group(0), m.end())
                fim = n if fim == -1 else fim + len(m.group(0))
                buf.append(sql[i:fim])
                i = fim
                continue
        if c == ";":
            stmt = "".join(buf).strip()
            if stmt:
                statements.append(stmt)
            buf = []
            i += 1
            continue
        buf.append(c)
        i += 1
    stmt = "".join(buf).strip()
    if stmt:
        statements.append(stmt)
    return statements


def bloco_parenteses(texto: str, inicio: int) -> tuple[str, int]:
    """Recebe o índice de um `(` e devolve (conteúdo interno, índice após o `)`)."""
    profundidade, aspa = 0, None
    for i in range(inicio, len(texto)):
        c = texto[i]
        if aspa:
            if c == aspa:
                aspa = None
            continue
        if c in "'\"":
            aspa = c
        elif c == "(":
            profundidade += 1
        elif c == ")":
            profundidade -= 1
            if profundidade == 0:
                return texto[inicio + 1:i], i + 1
    return texto[inicio + 1:], len(texto)


def separar_virgulas(texto: str) -> list[str]:
    partes, buf, profundidade, aspa = [], [], 0, None
    for c in texto:
        if aspa:
            buf.append(c)
            if c == aspa:
                aspa = None
            continue
        if c in "'\"":
            aspa = c
        elif c == "(":
            profundidade += 1
        elif c == ")":
            profundidade -= 1
        elif c == "," and profundidade == 0:
            partes.append("".join(buf).strip())
            buf = []
            continue
        buf.append(c)
    if "".join(buf).strip():
        partes.append("".join(buf).strip())
    return partes


def _lista_colunas(texto: str) -> list[str]:
    return [nome(c) for c in separar_virgulas(texto)]


def _remover_checks(texto: str) -> tuple[str, list[str]]:
    """Tira os CHECK (...) do texto para não confundir NOT NULL de dentro da expressão."""
    checks = []
    while True:
        m = re.search(r"\bCHECK\s*\(", texto, re.I)
        if not m:
            return texto, checks
        interno, fim = bloco_parenteses(texto, m.end() - 1)
        checks.append(espacos(interno))
        texto = texto[:m.start()] + texto[fim:]


_ON_DELETE = r"ON\s+DELETE\s+(CASCADE|SET\s+NULL|SET\s+DEFAULT|RESTRICT|NO\s+ACTION)"
_FIM_TIPO = re.compile(
    r"\b(NOT\s+NULL|NULL|DEFAULT|PRIMARY\s+KEY|UNIQUE|CHECK|REFERENCES|GENERATED|CONSTRAINT|COLLATE)\b", re.I
)


def _referencia(texto: str) -> dict | None:
    m = re.search(rf"\bREFERENCES\s+({IDENT})\s*(?:\(([^)]*)\))?", texto, re.I)
    if not m:
        return None
    on_delete = re.search(_ON_DELETE, texto[m.end():], re.I)
    return {
        "tabela": nome(m.group(1)),
        "colunas": _lista_colunas(m.group(2)) if m.group(2) else ["id"],
        "on_delete": espacos(on_delete.group(1)).upper() if on_delete else None,
    }


def _coluna(definicao: str) -> dict:
    m = re.match(r'\s*("[^"]+"|[\w$]+)\s+(.*)$', definicao, re.S)
    resto = m.group(2)
    fim = _FIM_TIPO.search(resto)
    tipo = espacos(resto[:fim.start()] if fim else resto)
    modificadores, checks = _remover_checks(resto[fim.start():] if fim else "")
    default = re.search(
        r"\bDEFAULT\s+(.+?)(?=\s+(?:NOT\s+NULL|NULL|PRIMARY|UNIQUE|REFERENCES|CONSTRAINT|GENERATED)\b|$)",
        modificadores, re.I | re.S,
    )
    pk = bool(re.search(r"\bPRIMARY\s+KEY\b", modificadores, re.I))
    return {
        "nome": nome(m.group(1)),
        "tipo": tipo,
        "obrigatorio": pk or bool(re.search(r"\bNOT\s+NULL\b", modificadores, re.I)),
        "pk": pk,
        "unique": bool(re.search(r"\bUNIQUE\b", modificadores, re.I)),
        "identity": bool(re.search(r"\bGENERATED\b.*\bIDENTITY\b", modificadores, re.I)),
        "default": espacos(default.group(1)) if default else None,
        "check": checks[0] if checks else None,
        "fk": _referencia(modificadores),
        "descricao": None,
    }


def _constraint_tabela(definicao: str) -> dict | None:
    m = re.match(rf"\s*(?:CONSTRAINT\s+({IDENT})\s+)?(PRIMARY\s+KEY|UNIQUE|CHECK|FOREIGN\s+KEY)\b\s*(.*)$",
                 definicao, re.I | re.S)
    if not m:
        return None
    tipo = espacos(m.group(2)).upper()
    corpo = m.group(3)
    interno, fim = bloco_parenteses(corpo, corpo.index("(")) if "(" in corpo else ("", 0)
    constraint = {"nome": nome(m.group(1)) if m.group(1) else None, "tipo": tipo}
    if tipo == "CHECK":
        constraint["expressao"] = espacos(interno)
    else:
        constraint["colunas"] = _lista_colunas(interno)
    if tipo == "FOREIGN KEY":
        constraint["referencia"] = _referencia(corpo[fim:])
    return constraint


def _dependencias(corpo: str) -> set[str]:
    """Nomes após FROM/JOIN/INTO/UPDATE, menos as CTEs. Filtrados depois contra objetos conhecidos."""
    ctes = {nome(n) for n in re.findall(rf"(?:\bWITH|,)\s+({IDENT})\s+AS\s*\(", corpo, re.I)}
    usados = {nome(n) for n in re.findall(rf"\b(?:FROM|JOIN|INTO|UPDATE)\s+(?:ONLY\s+)?({IDENT})", corpo, re.I)}
    return usados - ctes


def _chamadas(corpo: str) -> set[str]:
    return {nome(n) for n in re.findall(rf"\b({IDENT})\s*\(", corpo)}


def _unescape(literal: str) -> str | None:
    if literal.upper() == "NULL":
        return None
    return literal[1:-1].replace("''", "'")


def analisar_arquivo(caminho: str, conteudo: str, categoria: str) -> dict:
    """
    Devolve {objetos, fks, comentarios, avisos} de um arquivo.
    `categoria` vem da pasta: tabela, log, view, funcao, procedure, trigger, indice, seed.
    """
    resultado = {"objetos": [], "fks": [], "comentarios": [], "avisos": []}

    for stmt in separar_statements(conteudo):
        texto = stmt.strip()
        sql = texto + ";"

        m = re.match(rf"CREATE\s+(?:UNLOGGED\s+)?TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?({IDENT})\s*\(", texto, re.I)
        if m:
            corpo, _ = bloco_parenteses(texto, m.end() - 1)
            colunas, constraints = [], []
            for parte in separar_virgulas(corpo):
                c = _constraint_tabela(parte)
                if c:
                    constraints.append(c)
                elif parte:
                    colunas.append(_coluna(parte))
            por_nome = {c["nome"]: c for c in colunas}
            for c in constraints:
                if c["tipo"] == "PRIMARY KEY":
                    for col in c["colunas"]:
                        if col in por_nome:
                            por_nome[col].update(pk=True, obrigatorio=True)
                elif c["tipo"] == "UNIQUE" and len(c["colunas"]) == 1 and c["colunas"][0] in por_nome:
                    por_nome[c["colunas"][0]]["unique"] = True
                elif c["tipo"] == "FOREIGN KEY" and len(c["colunas"]) == 1 and c["colunas"][0] in por_nome:
                    por_nome[c["colunas"][0]]["fk"] = c["referencia"]
            resultado["objetos"].append({
                "nome": nome(m.group(1)), "tipo": "log" if categoria == "log" else "tabela",
                "arquivo": caminho, "sql": sql, "colunas": colunas,
                "constraints": [c for c in constraints if c["tipo"] != "PRIMARY KEY"],
            })
            continue

        m = re.match(rf"ALTER\s+TABLE\s+(?:IF\s+EXISTS\s+)?(?:ONLY\s+)?({IDENT})\s+ADD\s+(?:CONSTRAINT\s+({IDENT})\s+)?"
                     rf"FOREIGN\s+KEY\s*\(([^)]*)\)(.*)$", texto, re.I | re.S)
        if m:
            resultado["fks"].append({
                "tabela": nome(m.group(1)), "nome": nome(m.group(2)) if m.group(2) else None,
                "colunas": _lista_colunas(m.group(3)), "referencia": _referencia(m.group(4)), "arquivo": caminho,
            })
            continue

        m = re.match(rf"CREATE\s+(?:OR\s+REPLACE\s+)?(?:MATERIALIZED\s+)?VIEW\s+({IDENT})\s+AS\s+(.*)$", texto, re.I | re.S)
        if m:
            resultado["objetos"].append({
                "nome": nome(m.group(1)), "tipo": "view", "arquivo": caminho, "sql": sql,
                "colunas": [], "_deps": _dependencias(m.group(2)), "_chamadas": _chamadas(m.group(2)),
            })
            continue

        m = re.match(rf"CREATE\s+(?:OR\s+REPLACE\s+)?(FUNCTION|PROCEDURE)\s+({IDENT})\s*\(", texto, re.I)
        if m:
            argumentos, fim = bloco_parenteses(texto, m.end() - 1)
            resto = texto[fim:]
            retorno = re.search(r"\bRETURNS\s+(.+?)(?=\s+(?:LANGUAGE|AS)\b)", resto, re.I | re.S)
            linguagem = re.search(r"\bLANGUAGE\s+(\w+)", resto, re.I)
            corpo = re.search(r"(\$[A-Za-z_]*\$)(.*)\1", resto, re.S)
            corpo = corpo.group(2) if corpo else ""
            resultado["objetos"].append({
                "nome": nome(m.group(2)), "tipo": "funcao" if m.group(1).upper() == "FUNCTION" else "procedure",
                "arquivo": caminho, "sql": sql, "argumentos": espacos(argumentos),
                "retorno": espacos(retorno.group(1)) if retorno else None,
                "linguagem": linguagem.group(1).lower() if linguagem else None,
                "_deps": _dependencias(corpo), "_chamadas": _chamadas(corpo),
            })
            continue

        m = re.match(rf"CREATE\s+(?:OR\s+REPLACE\s+)?(?:CONSTRAINT\s+)?TRIGGER\s+({IDENT})\s+(BEFORE|AFTER|INSTEAD\s+OF)\s+"
                     rf"(.+?)\s+ON\s+({IDENT})\b(.*?)EXECUTE\s+(?:FUNCTION|PROCEDURE)\s+({IDENT})\s*\(", texto, re.I | re.S)
        if m:
            nivel = re.search(r"FOR\s+EACH\s+(ROW|STATEMENT)", m.group(5), re.I)
            resultado["objetos"].append({
                "nome": nome(m.group(1)), "tipo": "trigger", "arquivo": caminho, "sql": sql,
                "momento": espacos(m.group(2)).upper(), "eventos": espacos(m.group(3)).upper(),
                "tabela": nome(m.group(4)), "nivel": nivel.group(1).upper() if nivel else "STATEMENT",
                "funcao": nome(m.group(6)),
            })
            continue

        m = re.match(rf"CREATE\s+(UNIQUE\s+)?INDEX\s+(?:CONCURRENTLY\s+)?(?:IF\s+NOT\s+EXISTS\s+)?({IDENT})\s+ON\s+"
                     rf"(?:ONLY\s+)?({IDENT})\s*(?:USING\s+(\w+)\s*)?\(", texto, re.I)
        if m:
            colunas, fim = bloco_parenteses(texto, m.end() - 1)
            where = re.search(r"\bWHERE\s+(.*)$", texto[fim:], re.I | re.S)
            resultado["objetos"].append({
                "nome": nome(m.group(2)), "tipo": "indice", "arquivo": caminho, "sql": sql,
                "tabela": nome(m.group(3)), "unico": bool(m.group(1)), "metodo": (m.group(4) or "btree").lower(),
                "colunas_indice": [espacos(c) for c in separar_virgulas(colunas)],
                "condicao": espacos(where.group(1)) if where else None,
            })
            continue

        m = re.match(r"COMMENT\s+ON\s+(TABLE|VIEW|MATERIALIZED\s+VIEW|COLUMN|FUNCTION|PROCEDURE|TRIGGER|INDEX)\s+(.+?)\s+IS\s+"
                     r"('(?:[^']|'')*'|NULL)\s*$", texto, re.I | re.S)
        if m:
            tipo = espacos(m.group(1)).upper()
            alvo = espacos(m.group(2))
            if tipo in ("FUNCTION", "PROCEDURE"):
                alvo = alvo.split("(")[0]
            elif tipo == "TRIGGER":
                alvo = re.split(r"\s+ON\s+", alvo, flags=re.I)[0]
            resultado["comentarios"].append({
                "tipo": tipo, "alvo": nome(alvo), "texto": _unescape(m.group(3)), "arquivo": caminho,
            })
            continue

        if categoria == "seed" and re.match(r"UPDATE\s+catalogo_", texto, re.I):
            resultado.setdefault("classificacao", []).append(texto)

    return resultado


def analisar_carga(conteudo: str) -> dict:
    """
    Resumo de um script de carga (staging ou seed): quantos comandos, quais
    operações e quais tabelas ele escreve e lê. Não gera objetos do catálogo.
    """
    statements = separar_statements(conteudo)
    operacoes, escritas, lidas = [], set(), set()
    for stmt in statements:
        m = re.match(r"(WITH|INSERT|UPDATE|DELETE|TRUNCATE|COPY|SELECT|CREATE|ALTER|DROP)\b", stmt, re.I)
        if m:
            operacao = m.group(1).upper()
            if operacao == "WITH":  # CTE: a operação real vem depois do WITH
                real = re.search(r"\)\s*(INSERT|UPDATE|DELETE|SELECT)\b", stmt, re.I)
                operacao = real.group(1).upper() if real else "SELECT"
            if operacao not in operacoes:
                operacoes.append(operacao)
        escritas |= {nome(n) for n in re.findall(
            rf"\b(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM|TRUNCATE(?:\s+TABLE)?|COPY|CREATE\s+TABLE(?:\s+IF\s+NOT\s+EXISTS)?)\s+(?:ONLY\s+)?({IDENT})",
            stmt, re.I)}
        lidas |= {nome(n) for n in re.findall(rf"\b(?:FROM|JOIN)\s+(?:ONLY\s+)?({IDENT})", stmt, re.I)}
    ctes = {nome(n) for n in re.findall(rf"(?:\bWITH|,)\s+({IDENT})\s+AS\s*\(", conteudo, re.I)}
    ignorar = ctes | {"set", "select", "stdin", "lateral", "unnest", "jsonb_array_elements"}
    escritas -= ignorar
    return {
        "comandos": len(statements),
        "operacoes": operacoes,
        "escreve": sorted(escritas),
        "le": sorted(lidas - escritas - ignorar),
    }


def _literais(texto: str) -> list[str]:
    return [s.replace("''", "'") for s in re.findall(r"'((?:[^']|'')*)'", texto)]


def aplicar_classificacao(statements: list[str], objetos: dict[str, dict]) -> list[str]:
    """
    Interpreta os UPDATEs de seed_catalogo_classificacao.sql na mesma ordem em
    que o banco os executa. Cobre só os formatos usados nesse seed.
    """
    avisos = []
    for stmt in statements:
        corpo = espacos(stmt)

        m = re.match(r"UPDATE catalogo_tabela SET (.+?) WHERE (.+)$", corpo, re.I)
        if m and "FROM" not in m.group(1).upper():
            valores = dict(re.findall(r"(\w+)\s*=\s*'((?:[^']|'')*)'", m.group(1)))
            where = m.group(2)
            nomes = None
            if re.search(r"nome_tabela\s+IN\s*\(", where, re.I):
                nomes = set(_literais(re.search(r"IN\s*\(([^)]*)\)", where, re.I).group(1)))
            prefixo = re.search(r"nome_tabela\s+LIKE\s+'([^']*)'", where, re.I)
            excluidos = set(re.findall(r"nome_tabela\s*<>\s*'([^']*)'", where, re.I))
            so_nulos = re.findall(r"(\w+)\s+IS\s+NULL", where, re.I)
            for obj in objetos.values():
                if obj["tipo"] not in ("tabela", "log", "view"):
                    continue
                if nomes is not None and obj["nome"] not in nomes:
                    continue
                if prefixo and not obj["nome"].startswith(prefixo.group(1).replace("\\_", "_").rstrip("%")):
                    continue
                if obj["nome"] in excluidos or any(obj.get(campo) for campo in so_nulos):
                    continue
                obj.update(valores)
            continue

        if re.match(r"UPDATE catalogo_tabela AS ct SET regra_negocio", corpo, re.I):
            for tabela, regra in re.findall(r"\(\s*'((?:[^']|'')*)'\s*,\s*'((?:[^']|'')*)'\s*\)", corpo):
                if tabela in objetos:
                    objetos[tabela]["regra_negocio"] = regra.replace("''", "'")
            continue

        if re.match(r"UPDATE catalogo_coluna AS cc SET dado_pessoal_lgpd", corpo, re.I):
            for tabela, coluna in re.findall(r"\(\s*'([^']*)'\s*,\s*'([^']*)'\s*\)", corpo):
                _marcar_coluna(objetos, tabela, coluna, "lgpd", True, avisos)
            continue

        if re.match(r"UPDATE catalogo_coluna AS cc SET regra_negocio", corpo, re.I):
            for tabela, coluna, regra in re.findall(
                r"\(\s*'([^']*)'\s*,\s*'([^']*)'\s*,\s*'((?:[^']|'')*)'\s*\)", corpo
            ):
                _marcar_coluna(objetos, tabela, coluna, "regra_negocio", regra.replace("''", "'"), avisos)
            continue

        avisos.append(f"Seed de classificação: UPDATE não reconhecido: {corpo[:80]}...")
    return avisos


def _marcar_coluna(objetos, tabela, coluna, campo, valor, avisos):
    obj = objetos.get(tabela)
    if not obj:
        return  # tabelas do backend Java (fora do repositório) são ignoradas
    for col in obj.get("colunas", []):
        if col["nome"] == coluna:
            col[campo] = valor
            return
    avisos.append(f"Seed de classificação: coluna {tabela}.{coluna} não existe.")
