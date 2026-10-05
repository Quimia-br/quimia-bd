"""
Extractor de usuario: banco legado (modelo da outra equipe) -> staging do Quimia.

Devolve as colunas que o generate_users.py produz e que o loader lê
(nome, email, data_nasc, foto_url, senha, nivel_acesso, ultima_sessao),
mais data_alteracao, que o orchestrator usa como watermark e o loader ignora.

Tabela do legado: public.usuarios (confirmada no banco do RPA).

Legado -> Quimia
    nome             -> nome
    email            -> email
    data_nascimento  -> data_nasc
    url_foto         -> foto_url
    senha_hash       -> senha   (precisa ser bcrypt de 60 chars, senão o validate rejeita)
    data_cadastro    -> data_alteracao (só existe data de cadastro, então a carga
                        incremental só pega usuários novos, não edições)
    status           -> descartado (usuario não tem coluna de status)
    id_usuario (INT) -> descartado (o id do Quimia é UUID; a chave natural é o email)
"""
import pandas as pd
from sqlalchemy import text

from src.rpa.config import ENGINE_LEGADO

TABELA_LEGADO = "usuarios"

def main():

    def extrair(desde=None) -> pd.DataFrame:
        """
        desde=None     -> extração completa
        desde=<data>   -> só usuários cadastrados depois dessa data/hora.
        """
        query = f"""
            SELECT nome,
                email,
                data_nascimento AS data_nasc,
                url_foto        AS foto_url,
                senha_hash      AS senha,
                data_cadastro   AS data_alteracao
            FROM {TABELA_LEGADO}
        """
        params = {}
        if desde is not None:
            query += " WHERE data_cadastro > :desde"
            params["desde"] = desde

        with ENGINE_LEGADO.connect() as conn:
            df = pd.read_sql(text(query), conn, params=params)

        df["nivel_acesso"] = "usuario"  # legado não separa nível; admin/empresa são tabelas próprias lá
        df["ultima_sessao"] = None
        return df[["nome", "email", "data_nasc", "foto_url", "senha",
                "nivel_acesso", "ultima_sessao", "data_alteracao"]]

if __name__ == "__main__":
    main()