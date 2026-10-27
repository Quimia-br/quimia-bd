-- STAGING DDL — estante
-- Staging COMUM (não persistente) — TRUNCATE a cada rodada,
-- feito pelo loader.py antes do COPY.
--
-- id_usuario_raw fica como TEXT (não UUID) de propósito: staging
-- recebe o dado bruto sem tipagem, pra conseguir capturar formato
-- inválido (ex: "uuid-invalido-123") e rejeitar no validate, em vez
-- de estourar erro de tipo já no COPY.

CREATE TABLE IF NOT EXISTS stg_estante (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
    id_usuario_raw TEXT,
    nome_raw TEXT,
    ambiente_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
        CHECK (status IN ('pendente','ok','rejeitado')),
    motivo_rejeicao TEXT,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);