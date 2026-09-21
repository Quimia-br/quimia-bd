CREATE TABLE IF NOT EXISTS stg_produto (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
    nome_raw TEXT,
    id_marca_raw TEXT,
    descricao_raw TEXT,
    tipo_produto_raw TEXT,
    cod_barras_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
        CHECK (status IN ('pendente','ok','rejeitado')),
    motivo_rejeicao TEXT,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);