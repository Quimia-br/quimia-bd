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
        "nome": "nome_raw",
        "email": "email_raw",
        "data_nascimento": "data_nasc_raw",
        "data_cadastro": "cadastro_raw",
        "url_foto": "foto_url_raw",
        "status": "status_legado_raw",
    })

    df["senha_raw"] = _SENHA_TEMPORARIA_HASH
    df["nivel_acesso_raw"] = "padrao"

    if "foto_url_raw" not in df.columns:
        df["foto_url_raw"] = None

    df = df[df["status_legado_raw"].str.upper().isin(STATUS_IMPORTAVEIS)]
    if df.empty:
        return df


    colunas_staging = [
        "nome_raw", "email_raw", "data_nasc_raw",
        "senha_raw", "nivel_acesso_raw", "foto_url_raw", "cadastro_raw",
    ]

    return df[colunas_staging]
