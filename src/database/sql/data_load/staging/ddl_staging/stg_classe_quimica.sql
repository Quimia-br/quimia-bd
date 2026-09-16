DROP TABLE IF EXISTS stg_classe_quimica;

CREATE TABLE stg_classe_quimica(
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
    nome_raw TEXT,
    descricao_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
            CHECK (status in('pendente', 'ok', 'rejeitado')),
    motivo_rejeicao TEXT
);