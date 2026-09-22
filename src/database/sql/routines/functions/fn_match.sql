CREATE OR REPLACE FUNCTION fn_match_produtos(
    p_id_produto_a INTEGER,
    p_id_produto_b INTEGER
)
RETURNS TABLE (
    resultado VARCHAR(20),
    id_regra INTEGER,
    severidade VARCHAR(20),
    descricao_risco  TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_tem_compostos_a BOOLEAN;
    v_tem_compostos_b BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM fds f
        JOIN fds_composto fc ON fc.id_fds = f.id
        WHERE f.id_produto = p_id_produto_a
          AND f.ativo = TRUE
          AND fc.id_substancia IS NOT NULL
    ) INTO v_tem_compostos_a;

     SELECT EXISTS (
        SELECT 1
        FROM fds f
        JOIN fds_composto fc ON fc.id_fds = f.id
        WHERE f.id_produto = p_id_produto_b
          AND f.ativo = TRUE
          AND fc.id_substancia IS NOT NULL
    ) INTO v_tem_compostos_b;

    IF NOT v_tem_compostos_a OR NOT v_tem_compostos_b THEN
        RETURN QUERY
        SELECT 'nao_avaliado'::VARCHAR(20), NULL::INTEGER, NULL::VARCHAR(20), NULL::TEXT;
        RETURN;
    END IF;

    RETURN QUERY
    WITH compostos_a AS (
        SELECT DISTINCT fc.id_substancia
        FROM fds f
        JOIN fds_composto fc ON fc.id_fds = f.id
        WHERE f.id_produto = p_id_produto_a
          AND f.ativo = TRUE
          AND fc.id_substancia IS NOT NULL
    ),
    compostos_b AS (
        SELECT DISTINCT fc.id_substancia
        FROM fds f
        JOIN fds_composto fc ON fc.id_fds = f.id
        WHERE f.id_produto = p_id_produto_b
          AND f.ativo = TRUE
          AND fc.id_substancia IS NOT NULL
    ),
    classes_a AS (
        SELECT DISTINCT scq.id_classe_quimica
        FROM substancia_classe_quimica scq
        JOIN compostos_a ca ON ca.id_substancia = scq.id_substancia
    ),
    classes_b AS (
        SELECT DISTINCT scq.id_classe_quimica
        FROM substancia_classe_quimica scq
        JOIN compostos_b cb ON cb.id_substancia = scq.id_substancia
    ),
    regras_batidas AS (
        SELECT DISTINCT ir.id AS id_regra, ir.severidade, ir.descricao_risco
        FROM incompatibilidade_regra ir
        WHERE ir.ativo = TRUE
          AND (
              (
                  (ir.id_substancia_a IS NOT NULL AND EXISTS (SELECT 1 FROM compostos_a WHERE id_substancia = ir.id_substancia_a))
                  OR (ir.id_classe_a IS NOT NULL AND EXISTS (SELECT 1 FROM classes_a WHERE id_classe_quimica = ir.id_classe_a))
              )
              AND
              (
                  (ir.id_substancia_b IS NOT NULL AND EXISTS (SELECT 1 FROM compostos_b WHERE id_substancia = ir.id_substancia_b))
                  OR (ir.id_classe_b IS NOT NULL AND EXISTS (SELECT 1 FROM classes_b WHERE id_classe_quimica = ir.id_classe_b))
              )
          )
          OR (
              (
                  (ir.id_substancia_a IS NOT NULL AND EXISTS (SELECT 1 FROM compostos_b WHERE id_substancia = ir.id_substancia_a))
                  OR (ir.id_classe_a IS NOT NULL AND EXISTS (SELECT 1 FROM classes_b WHERE id_classe_quimica = ir.id_classe_a))
              )
              AND
              (
                  (ir.id_substancia_b IS NOT NULL AND EXISTS (SELECT 1 FROM compostos_a WHERE id_substancia = ir.id_substancia_b))
                  OR (ir.id_classe_b IS NOT NULL AND EXISTS (SELECT 1 FROM classes_a WHERE id_classe_quimica = ir.id_classe_b))
              )
          )
    )
    SELECT 'incompativel'::VARCHAR(20), id_regra, severidade, descricao_risco
    FROM regras_batidas

    UNION ALL

    -- só emite a linha "compativel" quando NENHUMA regra bateu
    SELECT 'compativel'::VARCHAR(20), NULL::INTEGER, NULL::VARCHAR(20), NULL::TEXT
    WHERE NOT EXISTS (SELECT 1 FROM regras_batidas)

    ORDER BY
        CASE severidade
            WHEN 'critica' THEN 1
            WHEN 'alta'    THEN 2
            WHEN 'media'   THEN 3
            WHEN 'baixa'   THEN 4
            ELSE 5
        END;
END;
$$;