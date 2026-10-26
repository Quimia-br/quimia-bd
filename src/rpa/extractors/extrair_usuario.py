"""
Extrator de usuario do banco legado -> Quimia (RPA).

    usuarios.nome            -> nome
    usuarios.email           -> email (UNIQUE no legado)
    usuarios.data_nascimento -> data_nasc
    usuarios.data_cadastro   -> cadastro (também usado como watermark)
    usuarios.url_foto        -> foto_url (CHECK no legado: só http:// ou https://)
    usuarios.status          -> filtro (ver STATUS_IMPORTAVEIS); NÃO vai pro CSV
    usuarios.senha_hash      -> NÃO copiado (ver decisão abaixo)
    usuarios.id_usuario      -> id_legado (só referência, não vai pro CSV)
"""
import bcrypt
import pandas as pd
from sqlalchemy import text

from src.rpa.config import ENGINE_LEGADO


STATUS_IMPORTAVEIS = {"ATIVO", "INATIVO", "PENDENTE", "BLOQUEADO", "DESATIVADO"}

_SENHA_TEMPORARIA_HASH = bcrypt.hashpw(b"trocar_no_primeiro_login", bcrypt.gensalt()).decode()


def extrair(desde=None) -> pd.DataFrame:
    if desde is not None:
        query = text("SELECT * FROM usuarios WHERE data_cadastro > :desde")
        params = {"desde": desde}
    else:
        query = text("SELECT * FROM usuarios")
        params = {}

    with ENGINE_LEGADO.connect() as conn:
        df = pd.read_sql(query, conn, params=params)

    if df.empty:
        return df


    df.columns = [c.strip().lower().replace(" ", "_") for c in df.columns]

    print("DEBUG - colunas que vieram do banco legado:", list(df.columns))

    df = df.rename(columns={
        "id_usuario": "id_legado",
        "data_nascimento": "data_nasc",
        "data_cadastro": "cadastro",
        "url_foto": "foto_url",
        "status": "status_legado",
    })

    df["senha"] = _SENHA_TEMPORARIA_HASH
    df["nivel_acesso"] = "usuario"

    if "foto_url" not in df.columns:
        df["foto_url"] = None

    df = df[df["status_legado"].str.upper().isin(STATUS_IMPORTAVEIS)]
    if df.empty:
        return df


    colunas_staging = [
        "nome", "email", "data_nasc",
        "senha", "nivel_acesso", "foto_url", "cadastro",
    ]

    return df[colunas_staging]
