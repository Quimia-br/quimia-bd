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
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(255) NOT NULL
);

CREATE TABLE empresa (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    cnpj VARCHAR(20) UNIQUE,
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE superficie (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    descricao VARCHAR(255)
);

CREATE TABLE usuario (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    data_nasc DATE,
    nivel_acesso VARCHAR(255)
);

CREATE TABLE ponto_parceiro (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    tipo VARCHAR(255),
    ativo BOOLEAN DEFAULT TRUE
);

CREATE TABLE produto (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(255) NOT NULL,
    id_marca INTEGER,
    descricao VARCHAR(255),
    tipo_produto VARCHAR(255),
    cod_barras VARCHAR(255)
);

CREATE TABLE fds (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto INTEGER,
    cas_numero VARCHAR(255),
    fonte_url TEXT,
    raw_json JSONB
);

CREATE TABLE fds_incompatibilidade (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_fds INTEGER,
    substancia_reagente VARCHAR(255),
    descricao_risco TEXT,
    severidade VARCHAR(255)
);

CREATE TABLE fds_composto (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_fds INTEGER,
    nome_composto VARCHAR(255),
    concentracao_min DECIMAL(10,4),
    concentracao_max DECIMAL(10,4)
);

CREATE TABLE fds_descarte (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_fds INTEGER,
    instrucao_descarte TEXT,
    tipo_residuo VARCHAR(255)
);

CREATE TABLE empresa_produto (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empresa INTEGER,
    id_produto INTEGER,
    ativo BOOLEAN DEFAULT TRUE,
    data_cadastro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE produto_superficie (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto INTEGER,
    id_superficie INTEGER,
    nivel_compativel DECIMAL(5,2)
);


CREATE TABLE localizacao_usuario (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario INTEGER,
    cep VARCHAR(20),
    estado VARCHAR(255),
    bairro VARCHAR(255),
    rua VARCHAR(255)
);

CREATE TABLE estante (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario INTEGER,
    nome VARCHAR(255),
    ambiente VARCHAR(255),
    criado_em TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE estante_produto (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto INTEGER,
    id_usuario INTEGER,
    id_estante INTEGER
);

CREATE TABLE historico_recomendacao (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto INTEGER,
    id_usuario INTEGER,
    id_usuario_produto INTEGER,
    id_superficie INTEGER,
    resultado VARCHAR(255),
    dosagem_sugerida TEXT,
    data_consulta TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);