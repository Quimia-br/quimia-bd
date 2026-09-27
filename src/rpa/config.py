import os

from dotenv import load_dotenv
from sqlalchemy import create_engine

load_dotenv()

RPA_DB_URL = os.environ["RPA_DB_URL"]
ENGINE = create_engine(RPA_DB_URL, pool_pre_ping=True)

QUIMIA_DB_URL = os.environ["DB_URL"]
ENGINE_QUIMIA = create_engine(QUIMIA_DB_URL, pool_pre_ping=True)