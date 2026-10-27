CREATE TABLE IF NOT EXISTS stg_sessao_acesso (
    id_usuario_raw  TEXT,
    ocorreu_em_raw  TEXT,
    id_batch        UUID NOT NULL,
    status          VARCHAR(20) DEFAULT 'pendente',
    motivo_rejeicao VARCHAR(200)
);

ALTER TABLE stg_sessao_acesso ALTER COLUMN id_usuario_raw TYPE TEXT;
ALTER TABLE stg_sessao_acesso ALTER COLUMN ocorreu_em_raw TYPE TEXT;
