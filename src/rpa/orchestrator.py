"""
Ponto de entrada único do RPA — chamado pelo agendador (cron / Task Scheduler / APScheduler).
"""
import logging
import os

from src.database.utils.staging import loader  # pipeline stg_* -> validate -> migrate já existente
from src.rpa import log_execucao
from src.rpa.extractors import extrair_usuario

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("rpa")

PROCESSOS = [
    ("usuario", extrair_usuario.extrair, "usuario"),
]


def rodar_processo(nome_processo: str, funcao_extracao, tabela_loader: str) -> None:
    id_execucao = log_execucao.iniciar(nome_processo)
    try:
        desde = log_execucao.ultimo_watermark(nome_processo)
        df = funcao_extracao(desde=desde)

        if df.empty:
            logger.info("%s: nenhuma linha nova, nada a fazer.", nome_processo)
            log_execucao.finalizar(id_execucao, status="sucesso", linhas=0)
            return

        caminho_csv = _salvar_csv_temporario(df, nome_processo)
        loader.rodar_pipeline(tabela_loader, caminho_csv)

        novo_watermark = df["data_alteracao"].max() if "data_alteracao" in df.columns else None
        log_execucao.finalizar(
            id_execucao,
            status="sucesso",
            linhas=len(df),
            watermark=novo_watermark,
        )
        logger.info("%s: %d linha(s) processada(s).", nome_processo, len(df))

    except Exception as e:
        logger.exception("%s: falhou.", nome_processo)
        log_execucao.finalizar(id_execucao, status="falha", erro=str(e))


def _salvar_csv_temporario(df, nome_processo: str) -> str:
    os.makedirs("src/rpa/_tmp", exist_ok=True)
    caminho = f"src/rpa/_tmp/{nome_processo}.csv"
    # o loader lê com csv.DictReader (vírgula) e converte "" em NULL
    df.to_csv(caminho, index=False)
    return caminho


def rodar_todos() -> None:
    if not PROCESSOS:
        logger.warning("Nenhum processo cadastrado em PROCESSOS ainda.")
        return
    for nome_processo, funcao_extracao, tabela_loader in PROCESSOS:
        rodar_processo(nome_processo, funcao_extracao, tabela_loader)


if __name__ == "__main__":
    rodar_todos()