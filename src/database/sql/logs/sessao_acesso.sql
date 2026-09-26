CREATE TABLE sessao_acesso (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario  UUID NOT NULL REFERENCES usuario(id),
    ocorreu_em  TIMESTAMPTZ NOT NULL DEFAULT now()
);
