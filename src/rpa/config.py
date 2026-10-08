import os

from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()



def _url(nome: str) -> str:
    # SQLAlchemy não aceita o esquema "postgres://" (usado pelo Aiven), só "postgresql://"
    return os.environ[nome].strip().replace("postgres://", "postgresql://", 1)


RPA_DB_URL = _url("RPA_DB_URL")
ENGINE = create_engine(RPA_DB_URL, pool_pre_ping=True)
ENGINE_LEGADO = ENGINE  # RPA_DB_URL aponta para o banco legado

QUIMIA_DB_URL = _url("DB_URL")
ENGINE_QUIMIA = create_engine(QUIMIA_DB_URL, pool_pre_ping=True)
