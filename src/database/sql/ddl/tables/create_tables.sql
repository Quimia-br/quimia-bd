DROP TABLE IF EXISTS historico_recomendacao CASCADE;
DROP TABLE IF EXISTS estante_produto CASCADE;
DROP TABLE IF EXISTS estante CASCADE;
DROP TABLE IF EXISTS localizacao_usuario CASCADE;
DROP TABLE IF EXISTS produto_superficie CASCADE;
DROP TABLE IF EXISTS sinonimo_pendente CASCADE;
DROP TABLE IF EXISTS incompatibilidade_regra CASCADE;
DROP TABLE IF EXISTS substancia_classe_quimica CASCADE;
DROP TABLE IF EXISTS substancia_sinonimo CASCADE;
DROP TABLE IF EXISTS fds_composto CASCADE;
DROP TABLE IF EXISTS fds_incompatibilidade CASCADE;
DROP TABLE IF EXISTS fds_descarte CASCADE;
DROP TABLE IF EXISTS fds CASCADE;
DROP TABLE IF EXISTS substancia CASCADE;
DROP TABLE IF EXISTS classe_quimica CASCADE;
DROP TABLE IF EXISTS empresa_produto CASCADE;
DROP TABLE IF EXISTS produto CASCADE;
DROP TABLE IF EXISTS ponto_parceiro CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;
DROP TABLE IF EXISTS empresa CASCADE;
DROP TABLE IF EXISTS marca CASCADE;
DROP TABLE IF EXISTS historico_match CASCADE;
DROP TABLE IF EXISTS sessao_acesso CASCADE;
DROP TABLE IF EXISTS log_auditoria CASCADE;

CREATE TABLE marca (
    id   INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome VARCHAR(255) NOT NULL UNIQUE
);

CREATE TABLE empresa (
    id     INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome   VARCHAR(255) NOT NULL,
    cnpj   VARCHAR(20) UNIQUE,
    ativo  BOOLEAN DEFAULT TRUE
);

CREATE TABLE usuario (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    nome VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    data_nasc DATE,
    nivel_acesso  VARCHAR(50) NOT NULL DEFAULT 'usuario'
        CHECK (nivel_acesso IN ('usuario', 'empresa', 'admin')),
    ultima_sessao TIMESTAMPTZ
);

CREATE TABLE classe_quimica (
    id        INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome      VARCHAR(255) NOT NULL UNIQUE,
    descricao TEXT
);

CREATE TABLE substancia (
    id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_canonico VARCHAR(255) NOT NULL,
    cas_numero    VARCHAR(20) UNIQUE,
    descricao     TEXT
);

CREATE TABLE substancia_sinonimo (
    id                    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_substancia         INTEGER NOT NULL,
    sinonimo              VARCHAR(255) NOT NULL,
    sinonimo_normalizado  VARCHAR(255) NOT NULL,
    CONSTRAINT un_sinonimo_normalizado UNIQUE (sinonimo_normalizado)
);

CREATE TABLE substancia_classe_quimica (
    id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_substancia     INTEGER NOT NULL,
    id_classe_quimica INTEGER NOT NULL,
    CONSTRAINT un_substancia_classe UNIQUE (id_substancia, id_classe_quimica)
);

CREATE TABLE produto (
    id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome         VARCHAR(255) NOT NULL,
    id_marca     INTEGER NOT NULL,
    descricao    TEXT,
    tipo_produto VARCHAR(50)
        CHECK (tipo_produto IN (
            'limpeza_geral','desinfetante','desincrustante',
            'desengraxante','alvejante','aromatizante','outro'
        )),
    cod_barras   VARCHAR(255) UNIQUE
);

CREATE TABLE fds (
    id               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto       INTEGER NOT NULL,
    versao           VARCHAR(20),
    data_atualizacao DATE,
    ativo            BOOLEAN NOT NULL DEFAULT TRUE,
    fonte_url        TEXT,
    raw_json         JSONB
);

    CREATE TABLE produto (
        id           INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        nome         VARCHAR(255) NOT NULL,
        id_marca     INTEGER NOT NULL,
        descricao    TEXT,
        tipo_produto VARCHAR(50)
            CHECK (tipo_produto IN (
                'limpeza_geral','desinfetante','desincrustante',
                'desengraxante','alvejante','aromatizante','outro'
            )),
        cod_barras   VARCHAR(255) UNIQUE
    );

    CREATE TABLE fds (
        id               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        id_produto       INTEGER NOT NULL,
        versao           VARCHAR(20),
        data_atualizacao DATE,
        ativo            BOOLEAN NOT NULL DEFAULT TRUE,
        fonte_url        TEXT,
        raw_json         JSONB
    );

    CREATE TABLE fds_primeiro_socorro (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_fds INTEGER NOT NULL,
    rota_exposicao VARCHAR(20) NOT NULL
        CHECK (rota_exposicao IN ('inalacao', 'pele', 'olhos', 'ingestao')),
    descricao TEXT,
    sintomas TEXT,
    tratamento_especial TEXT,
    atencao_medica_imediata  BOOLEAN NOT NULL DEFAULT FALSE
    );


    CREATE TABLE fds_composto (
        id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        id_fds            INTEGER NOT NULL,
        id_substancia     INTEGER,
        concentracao_min  NUMERIC(5,2),
        concentracao_max  NUMERIC(5,2),
        unidade_concentracao VARCHAR(20)
        CONSTRAINT chk_fds_composto_concentracao CHECK (
            concentracao_min IS NULL OR concentracao_max IS NULL
            OR concentracao_min <= concentracao_max
        )
    );

    CREATE TABLE fds_incompatibilidade (
        id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        id_fds INTEGER NOT NULL,
        id_substancia INTEGER,
        id_classe_quimica INTEGER,
        substancia_reagente VARCHAR(255),
        descricao_risco     TEXT,
        severidade          VARCHAR(20)
            CHECK (severidade IN ('baixa','media','alta','critica'))
    );

    CREATE TABLE fds_descarte (
        id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        id_fds              INTEGER NOT NULL,
        instrucao_descarte  TEXT,
        tipo_residuo        VARCHAR(50)
            CHECK (tipo_residuo IN ('quimico','biologico','comum','reciclavel','outro'))
    );

    CREATE TABLE incompatibilidade_regra (
        id               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        id_substancia_a  INTEGER,
        id_classe_a      INTEGER,
        id_substancia_b  INTEGER,
        id_classe_b      INTEGER,
        severidade       VARCHAR(20) NOT NULL
            CHECK (severidade IN ('baixa','media','alta','critica')),
        descricao_risco  TEXT NOT NULL,
        fonte            TEXT,
        ativo            BOOLEAN NOT NULL DEFAULT TRUE,
        CONSTRAINT chk_regra_lado_a CHECK (
            (id_substancia_a IS NOT NULL AND id_classe_a IS NULL) OR
            (id_substancia_a IS NULL AND id_classe_a IS NOT NULL)
        ),
        CONSTRAINT chk_regra_lado_b CHECK (
            (id_substancia_b IS NOT NULL AND id_classe_b IS NULL) OR
            (id_substancia_b IS NULL AND id_classe_b IS NOT NULL)
        )
    );

    CREATE TABLE sinonimo_pendente (
        id                       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        termo_bruto              VARCHAR(255) NOT NULL,
        cas_bruto                VARCHAR(20),
        id_fds                   INTEGER NOT NULL,
        status                   VARCHAR(20) NOT NULL DEFAULT 'pendente'
            CHECK (status IN ('pendente', 'resolvido', 'descartado')),
        id_substancia_resolvida  INTEGER,
        criado_em                TIMESTAMPTZ NOT NULL DEFAULT now(),
        resolvido_em             TIMESTAMPTZ
    );

CREATE TABLE fds_incompatibilidade (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_fds INTEGER NOT NULL,
    id_substancia INTEGER,
    id_classe_quimica INTEGER,
    substancia_reagente VARCHAR(255),
    descricao_risco     TEXT,
    severidade          VARCHAR(20)
        CHECK (severidade IN ('baixa','media','alta','critica'))
);

CREATE TABLE fds_descarte (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_fds              INTEGER NOT NULL,
    instrucao_descarte  TEXT,
    tipo_residuo        VARCHAR(50)
        CHECK (tipo_residuo IN ('quimico','biologico','comum','reciclavel','outro'))
);

CREATE TABLE incompatibilidade_regra (
    id               INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_substancia_a  INTEGER,
    id_classe_a      INTEGER,
    id_substancia_b  INTEGER,
    id_classe_b      INTEGER,
    severidade       VARCHAR(20) NOT NULL
        CHECK (severidade IN ('baixa','media','alta','critica')),
    descricao_risco  TEXT NOT NULL,
    fonte            TEXT,
    ativo            BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_regra_lado_a CHECK (
        (id_substancia_a IS NOT NULL AND id_classe_a IS NULL) OR
        (id_substancia_a IS NULL AND id_classe_a IS NOT NULL)
    ),
    CONSTRAINT chk_regra_lado_b CHECK (
        (id_substancia_b IS NOT NULL AND id_classe_b IS NULL) OR
        (id_substancia_b IS NULL AND id_classe_b IS NOT NULL)
    )
);

CREATE TABLE sinonimo_pendente (
    id                       INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    termo_bruto              VARCHAR(255) NOT NULL,
    cas_bruto                VARCHAR(20),
    id_fds                   INTEGER NOT NULL,
    status                   VARCHAR(20) NOT NULL DEFAULT 'pendente'
        CHECK (status IN ('pendente', 'resolvido', 'descartado')),
    id_substancia_resolvida  INTEGER,
    criado_em                TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolvido_em             TIMESTAMPTZ
);

CREATE TABLE empresa_produto (
    id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empresa     INTEGER NOT NULL,
    id_produto     INTEGER NOT NULL,
    ativo          BOOLEAN DEFAULT TRUE,
    data_cadastro  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT empresa_produto_unique UNIQUE (id_empresa, id_produto)
);

CREATE TABLE localizacao_usuario (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario  UUID NOT NULL,
    cep         VARCHAR(9),
    estado      VARCHAR(2),
    bairro      VARCHAR(255),
    rua         VARCHAR(255),
    numero      INTEGER,
    complemento VARCHAR(255),
    CONSTRAINT localizacao_usuario_unique UNIQUE (id_usuario)
);

CREATE TABLE estante (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario UUID NOT NULL,
    nome       VARCHAR(255),
    ambiente   VARCHAR(255),
    criado_em  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE estante_produto (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto  INTEGER NOT NULL,
    id_usuario  UUID NOT NULL,
    id_estante  INTEGER NOT NULL,
    CONSTRAINT estante_produto_unique UNIQUE (id_estante, id_produto)
);

CREATE TABLE historico_recomendacao (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_produto          INTEGER NOT NULL,
    id_usuario          UUID NOT NULL,
    resultado           VARCHAR(50)
        CHECK (resultado IN ('compativel','incompativel','atencao','nao_avaliado')),
    dosagem_sugerida    TEXT,
    data_consulta       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ponto_parceiro (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_empresa  INTEGER,
    nome        VARCHAR(255) NOT NULL,
    cep         VARCHAR(9),
    estado      VARCHAR(2),
    bairro      VARCHAR(255),
    rua         VARCHAR(255),
    numero      INTEGER,
    complemento VARCHAR(50),
    tipo        VARCHAR(50)
        CHECK (tipo IN ('compra', 'descarte')),
    ativo       BOOLEAN DEFAULT TRUE
);

CREATE TABLE historico_match (
    id                INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario        UUID NOT NULL,
    id_produto_a      INTEGER NOT NULL,
    id_produto_b      INTEGER NOT NULL,
    resultado         VARCHAR(20) NOT NULL
        CHECK (resultado IN ('compativel', 'incompativel', 'nao_avaliado')),
    id_regra          INTEGER,
    severidade        VARCHAR(20)
        CHECK (severidade IN ('baixa','media','alta','critica')),
    descricao_risco   TEXT,
    data_consulta     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_historico_match_par CHECK (id_produto_a < id_produto_b)
);

CREATE TABLE sessao_acesso (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario  UUID NOT NULL REFERENCES usuario(id),
    ocorreu_em  TIMESTAMPTZ NOT NULL DEFAULT now()
);


    CREATE TABLE IF NOT EXISTS log_auditoria (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    tabela_afetada VARCHAR(100) NOT NULL,
    operacao VARCHAR(10) NOT NULL CHECK (operacao IN ('INSERT','UPDATE','DELETE')),
    dado_anterior JSONB,
    dado_novo JSONB,
    usuario_db VARCHAR(100) NOT NULL,
    alterado_em TIMESTAMPTZ NOT NULL DEFAULT now()
    );
