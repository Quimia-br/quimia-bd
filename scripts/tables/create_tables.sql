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
    -- CHECK reintroduzido (sintaxe corrigida; o "[object Object]" da versão antiga não rodava)
    nivel_acesso  VARCHAR(255) NOT NULL DEFAULT 'usuario'
        CHECK (nivel_acesso IN ('usuario', 'empresa', 'admin'))
);

-- ATENÇÃO: "id_empresa" não estava no script oficial que você mandou,
-- mas o script de FKs referencia ele (fk_ponto_parceiro_empresa) e o schema
-- anterior tinha essa coluna. Reintroduzi como nullable (ponto parceiro sem
-- empresa dona = ponto público/genérico). Confirma se é isso mesmo.
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
    id_marca     INTEGER,               -- opcional: produto pode não ter marca cadastrada
    descricao    VARCHAR(255),
    tipo_produto VARCHAR(255)
        CHECK (tipo_produto IN (
            'limpeza_geral','desinfetante','desincrustante',
            'desengraxante','alvejante','aromatizante','outro'
        )),
    -- UNIQUE reintroduzido: tinha se perdido na última versão do schema oficial
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
    -- Sem UNIQUE(id_produto): decidido que um produto pode ter mais de uma FDS
    -- (ex: versões diferentes ao longo do tempo). Se precisar de "só a mais
    -- recente", trate isso na query/aplicação, não como constraint.
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
    -- Reintroduzido: evita a mesma empresa cadastrar o mesmo produto 2x
    CONSTRAINT empresa_produto_unique UNIQUE (id_empresa, id_produto)
);

CREATE TABLE produto_superficie (
    id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto        INTEGER NOT NULL,
    id_superficie     INTEGER NOT NULL,
    nivel_compativel  DECIMAL(5,2),
    -- Reintroduzido: evita duplicar a mesma combinação produto+superfície
    CONSTRAINT produto_superficie_unique UNIQUE (id_produto, id_superficie)
);

CREATE TABLE localizacao_usuario (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario  INTEGER NOT NULL,
    cep         VARCHAR(20),
    estado      VARCHAR(255),
    bairro      VARCHAR(255),
    rua         VARCHAR(255),
    -- Mantido 1:1 (1 localização por usuário), como decidido antes
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
    -- Evita duplicar o mesmo produto na mesma estante
    CONSTRAINT estante_produto_unique UNIQUE (id_produto, id_estante)
    -- NOTA (ponto 6 ainda em aberto): esta coluna id_usuario garante que existe
    -- um usuário válido, mas NÃO garante que é o MESMO dono da estante e do
    -- produto. Isso ainda precisa de um trigger (ou checagem na aplicação)
    -- comparando id_usuario aqui com estante.id_usuario. Não implementei
    -- porque isso ainda não foi confirmado/decidido por você.
);

CREATE TABLE historico_recomendacao (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto          INTEGER NOT NULL,
    id_usuario          INTEGER NOT NULL,
    -- ATENÇÃO: id_usuario_produto apareceu no script oficial sem FK e sem
    -- explicação. Deixei a coluna (nullable, sem FK) para não perder dado,
    -- mas isso precisa da sua confirmação: é resquício da antiga tabela
    -- user_produto (removida), ou deveria referenciar estante_produto.id
    -- agora que ela assumiu esse papel?
    id_usuario_produto  INTEGER,
    id_superficie       INTEGER,
    resultado           VARCHAR(255)
        CHECK (resultado IN ('compativel','incompativel','atencao','nao_avaliado')),
    dosagem_sugerida    TEXT,
    data_consulta       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);