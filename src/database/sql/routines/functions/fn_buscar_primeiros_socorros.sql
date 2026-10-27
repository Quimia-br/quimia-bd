DROP FUNCTION IF EXISTS buscar_primeiros_socorros(INTEGER);
DROP FUNCTION IF EXISTS fn_buscar_primeiros_socorros(INTEGER);

CREATE OR REPLACE FUNCTION buscar_primeiros_socorros(
    p_id_produto INTEGER
)
RETURNS TABLE (
    rota_exposicao          VARCHAR(20),
    descricao               TEXT,
    sintomas                TEXT,
    tratamento_especial     TEXT,
    atencao_medica_imediata BOOLEAN
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT ps.rota_exposicao,
           ps.descricao,
           ps.sintomas,
           ps.tratamento_especial,
           ps.atencao_medica_imediata
      FROM fds_primeiro_socorro ps
     WHERE ps.id_fds = (
               SELECT f.id
                 FROM fds f
                WHERE f.id_produto = p_id_produto
                  AND f.ativo = TRUE
                ORDER BY f.data_atualizacao DESC NULLS LAST, f.id DESC
                LIMIT 1
           )
     ORDER BY ps.id;
END;
$$;

COMMENT ON FUNCTION buscar_primeiros_socorros(INTEGER) IS 'Lista os primeiros socorros (fds_primeiro_socorro) da FDS ativa mais recente do produto; vazio se não houver FDS ou seção 04.';
