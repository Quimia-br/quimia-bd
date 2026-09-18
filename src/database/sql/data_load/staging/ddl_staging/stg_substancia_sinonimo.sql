-- STAGING DDL — substancia_sinonimo
-- Staging COMUM (não persistente) — TRUNCATE a cada rodada.

CREATE TABLE IF NOT EXISTS stg_substancia_sinonimo (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
    id_substancia_raw TEXT,
    sinonimo_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
        CHECK (status IN ('pendente','ok','rejeitado')),
    motivo_rejeicao TEXT,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);