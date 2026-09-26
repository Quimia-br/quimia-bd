DROP FUNCTION IF EXISTS buscar_dados_fds(INTEGER);
DROP FUNCTION IF EXISTS fn_buscar_dados_fds(INTEGER);

CREATE OR REPLACE FUNCTION buscar_dados_fds(
    p_id_produto INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_json JSONB;
BEGIN
    SELECT f.raw_json
      INTO v_json
      FROM fds f
     WHERE f.id_produto = p_id_produto
     AND f.ativo = TRUE
     ORDER BY f.data_atualizacao DESC NULLS LAST, f.id DESC
     LIMIT 1;

    RETURN v_json;
END;
$$;

COMMENT ON FUNCTION buscar_dados_fds(INTEGER) IS 'Retorna o raw_json da FDS ativa mais recente do produto (NULL se não houver).';
