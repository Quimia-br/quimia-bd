CREATE TABLE IF NOT EXISTS stg_substancia (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
    nome_canonico_raw TEXT,
    cas_numero_raw TEXT,
    descricao_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
            CHECK (status IN ('pendente','ok','rejeitado')),
    motivo_rejeicao TEXT,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
 