CREATE TABLE IF NOT EXISTS stg_usuario (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
    nome_raw TEXT,
    email_raw TEXT,
    data_nasc_raw TEXT,
    foto_url_raw TEXT,
    senha_raw TEXT,
    nivel_acesso_raw TEXT,
    ultima_sessao_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
    CHECK (status IN ('pendente','ok','rejeitado')),
    motivo_rejeicao TEXT,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

--CREATE INDEX IF NOT EXISTS idx_stg_usuario_batch  ON stg_usuario (id_batch);
--CREATE INDEX IF NOT EXISTS idx_stg_usuario_status ON stg_usuario (id_batch, status);


CREATE TABLE IF NOT EXISTS stg_empresa (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
    nome_raw TEXT,
    email_raw TEXT,
    cnpj_raw TEXT,
    ativo_raw TEXT,
    senha_raw TEXT,
    foto_url_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
        CHECK (status IN ('pendente','ok','rejeitado')),
    motivo_rejeicao TEXT,
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

--CREATE INDEX IF NOT EXISTS idx_stg_empresa_batch  ON stg_empresa (id_batch);
--CREATE INDEX IF NOT EXISTS idx_stg_empresa_status ON stg_empresa (id_batch, status);


CREATE OR REPLACE FUNCTION fn_data_valida(p_texto TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_texto IS NULL OR btrim(p_texto) = '' THEN
        RETURN FALSE;
    END IF;
    PERFORM p_texto::DATE;
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_timestamp_valido(p_texto TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_texto IS NULL OR btrim(p_texto) = '' THEN
        RETURN TRUE; -- nullable: vazio é válido (usuário nunca logou)
    END IF;
    PERFORM p_texto::TIMESTAMP;
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- stg_empresa já criada antes do e-mail de login: acrescenta a coluna sem precisar de DROP.
ALTER TABLE stg_empresa ADD COLUMN IF NOT EXISTS email_raw TEXT;
