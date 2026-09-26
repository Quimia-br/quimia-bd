CREATE TABLE log_auditoria (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabela_afetada  VARCHAR(100) NOT NULL,
    operacao        VARCHAR(10) NOT NULL CHECK (operacao IN ('INSERT','UPDATE','DELETE')),
    dado_anterior   JSONB,
    dado_novo       JSONB,
    usuario_db      VARCHAR(100) NOT NULL,
    alterado_em     TIMESTAMPTZ NOT NULL DEFAULT now()
);
