DROP TABLE IF EXISTS historico_recomendacao CASCADE;
DROP TABLE IF EXISTS estante_produto CASCADE;
DROP TABLE IF EXISTS estante CASCADE;
DROP TABLE IF EXISTS localizacao_usuario CASCADE;
DROP TABLE IF EXISTS produto_superficie CASCADE;
DROP TABLE IF EXISTS empresa_produto CASCADE;
DROP TABLE IF EXISTS fds_incompatibilidade CASCADE;
DROP TABLE IF EXISTS fds_composto CASCADE;
DROP TABLE IF EXISTS fds_descarte CASCADE;
DROP TABLE IF EXISTS fds CASCADE;
DROP TABLE IF EXISTS produto CASCADE;
DROP TABLE IF EXISTS ponto_parceiro CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;
DROP TABLE IF EXISTS superficie CASCADE;
DROP TABLE IF EXISTS empresa CASCADE;
DROP TABLE IF EXISTS marca CASCADE;


CREATE TABLE marca (
    id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(255) NOT NULL
);

CREATE TABLE empresa (
    id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome   VARCHAR(255) NOT NULL,
    cnpj   VARCHAR(20) UNIQUE,
    ativo  BOOLEAN DEFAULT TRUE
);

CREATE TABLE superficie (
    id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome      VARCHAR(255) NOT NULL,
    descricao VARCHAR(255)
);

CREATE TABLE usuario (
    id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome          VARCHAR(255) NOT NULL,
    email         VARCHAR(255) UNIQUE NOT NULL,
    data_nasc     DATE,
    nivel_acesso  VARCHAR(255) NOT NULL DEFAULT 'usuario'
        CHECK (nivel_acesso IN ('usuario', 'empresa', 'admin'))
);

CREATE TABLE ponto_parceiro (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empresa INTEGER,
    nome       VARCHAR(255) NOT NULL,
    latitude   DECIMAL(10,8),
    longitude  DECIMAL(11,8),
    tipo       VARCHAR(255),
    ativo      BOOLEAN DEFAULT TRUE
);

CREATE TABLE produto (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome         VARCHAR(255) NOT NULL,
    id_marca     INTEGER,
    descricao    VARCHAR(255),
    tipo_produto VARCHAR(255)
        CHECK (tipo_produto IN (
            'limpeza_geral','desinfetante','desincrustante',
            'desengraxante','alvejante','aromatizante','outro'
        )),
   
    cod_barras   VARCHAR(255) UNIQUE
);

CREATE INDEX idx_produto_cod_barras ON produto (cod_barras);
CREATE INDEX idx_produto_nome       ON produto (nome);

CREATE TABLE fds (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto INTEGER NOT NULL,
    cas_numero VARCHAR(255),
    fonte_url  TEXT,
    raw_json   JSONB
);

CREATE INDEX idx_fds_produto ON fds (id_produto);

CREATE TABLE fds_incompatibilidade (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_fds              INTEGER NOT NULL,
    substancia_reagente VARCHAR(255),
    descricao_risco     TEXT,
    severidade          VARCHAR(255)
        CHECK (severidade IN ('baixa','media','alta','critica'))
);

CREATE TABLE fds_composto (
    id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_fds            INTEGER NOT NULL,
    nome_composto     VARCHAR(255),
    concentracao_min  DECIMAL(10,4),
    concentracao_max  DECIMAL(10,4)
);

CREATE TABLE fds_descarte (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_fds              INTEGER NOT NULL,
    instrucao_descarte  TEXT,
    tipo_residuo        VARCHAR(255)
        CHECK (tipo_residuo IN ('quimico','biologico','comum','reciclavel','outro'))
);

CREATE TABLE empresa_produto (
    id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empresa     INTEGER NOT NULL,
    id_produto     INTEGER NOT NULL,
    ativo          BOOLEAN DEFAULT TRUE,
    data_cadastro  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT empresa_produto_unique UNIQUE (id_empresa, id_produto)
);

CREATE TABLE produto_superficie (
    id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto        INTEGER NOT NULL,
    id_superficie     INTEGER NOT NULL,
    nivel_compativel  DECIMAL(5,2),
    CONSTRAINT produto_superficie_unique UNIQUE (id_produto, id_superficie)
);

CREATE TABLE localizacao_usuario (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario  INTEGER NOT NULL,
    cep         VARCHAR(20),
    estado      VARCHAR(255),
    bairro      VARCHAR(255),
    rua         VARCHAR(255),
    CONSTRAINT localizacao_usuario_unique UNIQUE (id_usuario)
);

CREATE TABLE estante (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario INTEGER NOT NULL,
    nome       VARCHAR(255),
    ambiente   VARCHAR(255),
    criado_em  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE estante_produto (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto  INTEGER NOT NULL,
    id_usuario  INTEGER NOT NULL,
    id_estante  INTEGER NOT NULL,
    CONSTRAINT estante_produto_unique UNIQUE (id_produto, id_estante)
);

CREATE TABLE historico_recomendacao (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto          INTEGER NOT NULL,
    id_usuario          INTEGER NOT NULL,
    --id_usuario_produto  INTEGER,
    id_superficie       INTEGER,
    resultado           VARCHAR(255)
        CHECK (resultado IN ('compativel','incompativel','atencao','nao_avaliado')),
    dosagem_sugerida    TEXT,
    data_consulta       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);