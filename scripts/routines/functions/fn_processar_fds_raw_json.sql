DROP FUNCTION IF EXISTS fn_trg_processar_fds_raw_json();
DROP FUNCTION IF EXISTS trg_processar_fds_raw_json();

CREATE OR REPLACE FUNCTION fn_processar_fds_raw_json(
    p_id_fds INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_raw JSONB;
BEGIN
    SELECT f.raw_json
      INTO v_raw
      FROM fds f
     WHERE f.id = p_id_fds;

    IF v_raw IS NULL THEN
        RAISE EXCEPTION 'FDS % sem raw_json.', p_id_fds;
    END IF;

    DELETE FROM fds_composto          WHERE id_fds = p_id_fds;
    DELETE FROM fds_incompatibilidade WHERE id_fds = p_id_fds;
    DELETE FROM fds_descarte          WHERE id_fds = p_id_fds;

    INSERT INTO fds_composto (
        id_fds,
        nome_composto,
        cas_number,
        concentracao_min,
        concentracao_max
    )
    SELECT
        p_id_fds,
        COALESCE(c->>'nome_composto', c->>'nome', c->>'substancia') AS nome_composto,
        COALESCE(c->>'cas_number', c->>'cas', c->>'numero_cas')      AS cas_number,
        NULLIF(COALESCE(c->>'concentracao_min', c->>'min', c->>'conc_min'), '')::NUMERIC(5,2),
        NULLIF(COALESCE(c->>'concentracao_max', c->>'max', c->>'conc_max'), '')::NUMERIC(5,2)
    FROM jsonb_array_elements(
        COALESCE(
            v_raw #> '{secoes,03_composicao,ingredientes}',
            v_raw #> '{secoes,composicao,ingredientes}',
            v_raw #> '{compostos}',
            '[]'::jsonb
        )
    ) c;

    INSERT INTO fds_incompatibilidade (
        id_fds,
        substancia_reagente,
        descricao_risco,
        severidade
    )
    SELECT
        p_id_fds,
        COALESCE(i->>'substancia_reagente', i->>'substancia', i->>'agente') AS substancia_reagente,
        COALESCE(i->>'descricao_risco', i->>'risco', i->>'descricao')         AS descricao_risco,
        COALESCE(i->>'severidade', 'media')::VARCHAR(20)                      AS severidade
    FROM jsonb_array_elements(
        COALESCE(
            v_raw #> '{secoes,10_estabilidade_reatividade,incompatibilidades}',
            v_raw #> '{secoes,incompatibilidades}',
            v_raw #> '{incompatibilidades}',
            '[]'::jsonb
        )
    ) i;

    INSERT INTO fds_descarte (
        id_fds,
        instrucao_descarte,
        tipo_residuo
    )
    SELECT
        p_id_fds,
        COALESCE(d->>'instrucao_descarte', d->>'instrucao', d->>'orientacao') AS instrucao_descarte,
        COALESCE(d->>'tipo_residuo', 'comum')::VARCHAR(50)                     AS tipo_residuo
    FROM jsonb_array_elements(
        COALESCE(
            v_raw #> '{secoes,12_descarte_transporte,descarte}',
            v_raw #> '{secoes,descarte,itens}',
            v_raw #> '{descarte}',
            '[]'::jsonb
        )
    ) d;
END;
$$;