CREATE OR REPLACE PROCEDURE sp_registrar_consulta_match(
    p_id_usuario UUID,
    p_id_produto_a INTEGER,
    p_id_produto_b INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_produto_a INTEGER;
    v_id_produto_b INTEGER;
    v_resultado VARCHAR(20);
    v_id_regra INTEGER;
    v_severidade VARCHAR(20);
    v_descricao_risco TEXT;
BEGIN
    IF p_id_produto_a = p_id_produto_b THEN
        RAISE EXCEPTION 'Não é possível comparar um produto com ele mesmo (id_produto = %)', p_id_produto_a;
    END IF;

    v_id_produto_a := LEAST(p_id_produto_a, p_id_produto_b);
    v_id_produto_b := GREATEST(p_id_produto_a, p_id_produto_b);

    SELECT resultado, id_regra, severidade, descricao_risco
    INTO v_resultado, v_id_regra, v_severidade, v_descricao_risco
    FROM fn_match_produtos(v_id_produto_a, v_id_produto_b)
    LIMIT 1;

    INSERT INTO historico_match (
        id_usuario, id_produto_a, id_produto_b,
        resultado, id_regra, severidade, descricao_risco
    ) VALUES (
        p_id_usuario, v_id_produto_a, v_id_produto_b,
        v_resultado, v_id_regra, v_severidade, v_descricao_risco
    );

    COMMIT;
END;
$$;