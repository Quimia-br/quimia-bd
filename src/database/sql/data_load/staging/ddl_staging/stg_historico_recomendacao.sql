CREATE TABLE IF NOT EXISTS stg_historico_recomendacao (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
    id_produto_raw TEXT,
    id_usuario_raw TEXT,
    resultado_raw TEXT,
    dosagem_sugerida_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
        CHECK (status IN ('pendente','ok','rejeitado')),
    motivo_rejeicao TEXT,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);