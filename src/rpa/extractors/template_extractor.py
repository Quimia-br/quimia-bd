"""
TEMPLATE do extractor, atualizar para cada tabela especifica
(ex: extrair_empresa.py, extrair_produto.py) seguindo os ajustes:
  1. o nome da tabela/query no banco legado
  2. a coluna de watermark, se essa tabela usar extração incremental
  3. o rename de colunas pro formato que a staging do Quimia espera
     (mesmas colunas que os generate_*.py já produzem pra essa tabela)

Não precisa criar um extrator por tabela do zero — a lógica é sempre:
ler do legado -> devolver DataFrame já no formato esperado pela staging.
"""
import pandas as pd
from sqlalchemy import text

from src.rpa.config import ENGINE_LEGADO


def extrair(desde=None) -> pd.DataFrame:
    """
    Extrai a tabela do banco legado.

    desde=None      -> extração completa (usar em tabelas pequenas, truncate-reload)
    desde=<valor>   -> extração incremental (WHERE data_alteracao > :desde)
    """
    if desde is not None:
        query = text(
            """
            SELECT *
            FROM tabela_legado
            WHERE data_alteracao > :desde
            """
        )
        params = {"desde": desde}
    else:
        query = text("SELECT * FROM tabela_legado")
        params = {}

    with ENGINE_LEGADO.connect() as conn:
        df = pd.read_sql(query, conn, params=params)



    return df