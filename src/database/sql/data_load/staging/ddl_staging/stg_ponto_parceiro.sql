CREATE TABLE IF NOT EXISTS stg_ponto_parceiro (
    id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_batch UUID NOT NULL,
 
    id_empresa_raw TEXT,
    nome_raw TEXT,
    cep_raw TEXT,
    estado_raw TEXT,
    bairro_raw TEXT,
    rua_raw TEXT,
    numero_raw TEXT,
    complemento_raw TEXT,
    tipo_raw TEXT,
    ativo_raw TEXT,
    latitude_raw TEXT,
    longitude_raw TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pendente'
                            CHECK (status IN ('pendente','ok','rejeitado')),
    motivo_rejeicao TEXT,
 
    criado_em TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
 
 
CREATE OR REPLACE FUNCTION fn_inteiro_valido(p_texto TEXT)
RETURNS BOOLEAN AS $$
BEGIN
    IF p_texto IS NULL OR btrim(p_texto) = '' THEN
        RETURN FALSE;
    END IF;
    PERFORM p_texto::INTEGER;
    RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- tabelas de staging persistem entre execuções (CREATE ... IF NOT EXISTS): bancos que já tinham
-- a stg_ponto_parceiro sem as coordenadas ganham as colunas aqui.
ALTER TABLE stg_ponto_parceiro ADD COLUMN IF NOT EXISTS latitude_raw TEXT;
ALTER TABLE stg_ponto_parceiro ADD COLUMN IF NOT EXISTS longitude_raw TEXT;
