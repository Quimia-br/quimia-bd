CREATE TABLE IF NOT EXISTS stg_incompatibilidade_regra (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
    id_substancia_a_raw TEXT,
    id_classe_a_raw TEXT,
    id_substancia_b_raw TEXT,
    id_classe_b_raw TEXT,
    severidade_raw TEXT,
    descricao_risco_raw TEXT,
    fonte_raw TEXT,
    ativo_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
        CHECK (status IN ('pendente','ok','rejeitado')),
    motivo_rejeicao TEXT,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);