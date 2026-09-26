DROP FUNCTION IF EXISTS buscar_incompatibilidades(INTEGER);
DROP FUNCTION IF EXISTS fn_buscar_incompatibilidades(INTEGER);

CREATE OR REPLACE FUNCTION buscar_incompatibilidades(
    p_id_produto INTEGER
)
RETURNS TABLE (
    substancia_reagente VARCHAR(255),
    descricao_risco     TEXT,
    severidade          VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT fi.substancia_reagente,
           fi.descricao_risco,
           fi.severidade
      FROM fds f
      JOIN fds_incompatibilidade fi ON fi.id_fds = f.id
     WHERE f.id_produto = p_id_produto;
END;
$$;

COMMENT ON FUNCTION buscar_incompatibilidades(INTEGER) IS 'Lista as incompatibilidades declaradas nas FDS do produto (fds_incompatibilidade).';
