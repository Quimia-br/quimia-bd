CREATE TABLE IF NOT EXISTS stg_sessao_acesso (
    id_usuario_raw  VARCHAR(100),
    ocorreu_em_raw  VARCHAR(100),
    id_batch        UUID NOT NULL,
    status          VARCHAR(20) DEFAULT 'pendente',
    motivo_rejeicao VARCHAR(200)
);