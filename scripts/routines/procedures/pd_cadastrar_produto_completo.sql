DROP PROCEDURE IF EXISTS cadastrar_produto_completo(
    VARCHAR, INTEGER, TEXT, VARCHAR, VARCHAR,
    INTEGER, VARCHAR, DATE, TEXT, JSONB
);

DROP PROCEDURE IF EXISTS pd_cadastrar_produto_completo(
    VARCHAR, INTEGER, TEXT, VARCHAR, VARCHAR,
    INTEGER, VARCHAR, DATE, TEXT, JSONB
);

CREATE OR REPLACE PROCEDURE cadastrar_produto_completo(
    p_nome             VARCHAR,
    p_id_marca         INTEGER,
    p_descricao        TEXT,
    p_tipo_produto     VARCHAR,
    p_cod_barras       VARCHAR,
    p_id_empresa       INTEGER,
    p_versao_fds       VARCHAR DEFAULT NULL,
    p_data_atualizacao DATE    DEFAULT NULL,
    p_fonte_url        TEXT    DEFAULT NULL,
    p_raw_json         JSONB   DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_produto INTEGER;
BEGIN
    INSERT INTO produto (nome, id_marca, descricao, tipo_produto, cod_barras)
    VALUES (p_nome, p_id_marca, p_descricao, p_tipo_produto, p_cod_barras)
    RETURNING id INTO v_id_produto;

    INSERT INTO empresa_produto (id_empresa, id_produto, ativo, data_cadastro)
    VALUES (p_id_empresa, v_id_produto, TRUE, CURRENT_TIMESTAMP);

    INSERT INTO fds (id_produto, versao, data_atualizacao, fonte_url, raw_json)
    VALUES (v_id_produto, p_versao_fds, p_data_atualizacao, p_fonte_url, p_raw_json);
END;
$$;