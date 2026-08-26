DROP FUNCTION IF EXISTS buscar_compatibilidade(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS fn_buscar_compatibilidade(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION buscar_compatibilidade(
    p_id_produto    INTEGER,
    p_id_superficie INTEGER
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nivel NUMERIC(5,2);
BEGIN
    SELECT ps.nivel_compativel
      INTO v_nivel
      FROM produto_superficie ps
     WHERE ps.id_produto = p_id_produto
       AND ps.id_superficie = p_id_superficie;

    RETURN v_nivel;
END;
$$;