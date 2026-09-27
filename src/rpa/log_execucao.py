"""
Helpers para registrar e consultar execuções do RPA em log_rpa_execucao.

Toda execução DEVE terminar com finalizar() chamado, mesmo em erro —
nunca deixar uma linha travada em status='rodando' (orquestrador.py
garante isso via try/except).
"""
from sqlalchemy import text

from src.rpa.config import ENGINE_QUIMIA


def iniciar(nome_processo: str) -> int:
    """Registra o início de uma execução e retorna o id gerado."""
    with ENGINE_QUIMIA.begin() as conn:
        resultado = conn.execute(
            text(
                """
                INSERT INTO log_rpa_execucao (nome_processo, status)
                VALUES (:nome_processo, 'rodando')
                RETURNING id
                """
            ),
            {"nome_processo": nome_processo},
        )
        return resultado.scalar_one()


def finalizar(
    id_execucao: int,
    status: str,
    linhas: int | None = None,
    erro: str | None = None,
    watermark=None,
):
    """Atualiza a execução com o resultado final ('sucesso' ou 'falha')."""
    with ENGINE_QUIMIA.begin() as conn:
        conn.execute(
            text(
                """
                UPDATE log_rpa_execucao
                SET finalizado_em = now(),
                    status = :status,
                    linhas_processadas = :linhas,
                    mensagem_erro = :erro,
                    ultimo_watermark = :watermark
                WHERE id = :id_execucao
                """
            ),
            {
                "status": status,
                "linhas": linhas,
                "erro": erro,
                "watermark": watermark,
                "id_execucao": id_execucao,
            },
        )


def ultimo_watermark(nome_processo: str):
    """
    Busca o watermark da última execução com sucesso, para extração incremental.
    Retorna None se nunca rodou com sucesso (o extrator deve então extrair tudo).
    """
    with ENGINE_QUIMIA.connect() as conn:
        resultado = conn.execute(
            text(
                """
                SELECT ultimo_watermark
                FROM log_rpa_execucao
                WHERE nome_processo = :nome_processo
                  AND status = 'sucesso'
                ORDER BY finalizado_em DESC
                LIMIT 1
                """
            ),
            {"nome_processo": nome_processo},
        )
        linha = resultado.first()
        return linha[0] if linha else None