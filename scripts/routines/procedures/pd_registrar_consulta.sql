DROP PROCEDURE IF EXISTS registrar_consulta(INTEGER, INTEGER, INTEGER, TEXT);
DROP PROCEDURE IF EXISTS pd_registrar_consulta(INTEGER, INTEGER, INTEGER, TEXT);

CREATE OR REPLACE PROCEDURE registrar_consulta(
    p_id_usuario    INTEGER,
    p_id_produto    INTEGER,
    p_id_superficie INTEGER DEFAULT NULL,
    p_dosagem       TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nivel NUMERIC(5,2);
    v_resultado VARCHAR(50);
BEGIN
    IF p_id_superficie IS NULL THEN
        v_resultado := 'nao_avaliado';
    ELSE
        v_nivel := buscar_compatibilidade(p_id_produto, p_id_superficie);

        v_resultado := CASE
            WHEN v_nivel IS NULL THEN 'nao_avaliado'
            WHEN v_nivel >= 0.70 THEN 'compativel'
            WHEN v_nivel >= 0.40 THEN 'atencao'
            ELSE 'incompativel'
        END;
    END IF;

    INSERT INTO historico_recomendacao (
        id_produto,
        id_usuario,
        id_superficie,
        resultado,
        dosagem_sugerida
    ) VALUES (
        p_id_produto,
        p_id_usuario,
        p_id_superficie,
        v_resultado,
        p_dosagem
    );
END;
$$;