DROP TABLE IF EXISTS catalogo_coluna CASCADE;
DROP TABLE IF EXISTS catalogo_tabela CASCADE;

CREATE TABLE catalogo_tabela (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_tabela     VARCHAR(100) NOT NULL UNIQUE,
    tipo_objeto     VARCHAR(10)  NOT NULL CHECK (tipo_objeto IN ('tabela', 'view')),
    dominio         VARCHAR(30)
        CHECK (dominio IN ('cadastro', 'fds', 'curadoria', 'interacao', 'auditoria', 'dimensional', 'fato', 'catalogo')),
    descricao       TEXT,
    regra_negocio   TEXT,
    nivel_acesso    VARCHAR(20)
        CHECK (nivel_acesso IN ('publico', 'interno', 'restrito')),
    responsavel     VARCHAR(100),
    atualizado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE catalogo_coluna (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_catalogo_tabela  INTEGER NOT NULL REFERENCES catalogo_tabela(id) ON DELETE CASCADE,
    nome_coluna         VARCHAR(100) NOT NULL,
    tipo_dado           VARCHAR(100),
    obrigatorio         BOOLEAN,
    chave_primaria      BOOLEAN NOT NULL DEFAULT FALSE,
    referencia_tabela   VARCHAR(100),
    descricao_negocio   TEXT,
    regra_negocio       TEXT,
    dado_pessoal_lgpd   BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT un_catalogo_coluna UNIQUE (id_catalogo_tabela, nome_coluna)
);
