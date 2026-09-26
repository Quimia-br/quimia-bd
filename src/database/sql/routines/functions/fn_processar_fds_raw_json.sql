-- ============================================================
-- fn_processar_fds_raw_json — parser JSON -> tabelas normalizadas
--
-- Lê fds.raw_json (contrato produzido por fds_parser.py) e
-- materializa fds_composto e fds_descarte. Idempotente: reprocessar
-- a mesma FDS apaga e recria os filhos.
--
-- Resolução de substância (por composto, nessa ordem):
--   1. CAS exato          -> substancia.cas_numero
--   2. sinônimo conhecido -> substancia_sinonimo.sinonimo_normalizado
--   3. nome canônico      -> substancia.nome_canonico (normalizado)
--   4. não resolveu       -> fds_composto.id_substancia fica NULL
--                            + vira pendência em sinonimo_pendente
--                            para curadoria humana (fn_resolver_pendencia)
--
-- fds_incompatibilidade NÃO é populada por esta function — o parser
-- não extrai incompatibilidades estruturadas (só grava texto bruto
-- em secoes.10, que já fica preservado no próprio raw_json). Essa
-- tabela continua sendo curadoria manual via incompatibilidade_regra
-- + fn_match_produtos. Deixamos aqui um tratamento defensivo caso
-- o parser um dia passe a extrair isso (contrato já prevê o campo
-- como opcional), mas hoje o array sempre vem vazio/ausente.
--
-- Requer extensão unaccent (já habilitada no create_tables.sql).
-- ============================================================

CREATE OR REPLACE FUNCTION fn_processar_fds_raw_json(
    p_id_fds INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_raw               JSONB;
    v_composto          JSONB;
    v_incompatibilidade JSONB;
    v_descarte          JSONB;

    v_nome_raw          TEXT;
    v_cas_raw           TEXT;
    v_nome_normalizado  TEXT;
    v_id_substancia     INTEGER;
BEGIN
    SELECT f.raw_json
      INTO v_raw
      FROM fds f
     WHERE f.id = p_id_fds;

    IF v_raw IS NULL THEN
        RAISE EXCEPTION 'FDS % sem raw_json.', p_id_fds;
    END IF;

    -- ---- idempotência: limpa o que essa FDS já tinha gerado ----
    DELETE FROM fds_composto          WHERE id_fds = p_id_fds;
    DELETE FROM fds_incompatibilidade WHERE id_fds = p_id_fds;
    DELETE FROM fds_descarte          WHERE id_fds = p_id_fds;

    -- pendências ainda não resolvidas desta FDS são recriadas do zero
    -- a cada reprocessamento; as já resolvidas/descartadas viram
    -- histórico e não são tocadas.
    DELETE FROM sinonimo_pendente
     WHERE id_fds = p_id_fds
       AND status = 'pendente';

    -- ================================================================
    -- SEÇÃO 03 — compostos (obrigatório no contrato do parser)
    -- ================================================================
    FOR v_composto IN
        SELECT jsonb_array_elements(
            COALESCE(v_raw #> '{secoes,03,compostos}', '[]'::jsonb)
        )
    LOOP
        v_nome_raw := v_composto ->> 'nome';
        v_cas_raw  := v_composto ->> 'cas_numero';
        v_id_substancia := NULL;

        v_nome_normalizado := CASE
            WHEN v_nome_raw IS NOT NULL THEN lower(unaccent(btrim(v_nome_raw)))
            ELSE NULL
        END;

        -- 1. CAS exato
        IF v_cas_raw IS NOT NULL THEN
            SELECT s.id INTO v_id_substancia
            FROM substancia s
            WHERE s.cas_numero = btrim(v_cas_raw);
        END IF;

        -- 2. sinônimo normalizado
        IF v_id_substancia IS NULL AND v_nome_normalizado IS NOT NULL THEN
            SELECT ss.id_substancia INTO v_id_substancia
            FROM substancia_sinonimo ss
            WHERE ss.sinonimo_normalizado = v_nome_normalizado;
        END IF;

        -- 3. nome canônico normalizado
        IF v_id_substancia IS NULL AND v_nome_normalizado IS NOT NULL THEN
            SELECT s.id INTO v_id_substancia
            FROM substancia s
            WHERE lower(unaccent(btrim(s.nome_canonico))) = v_nome_normalizado;
        END IF;

        INSERT INTO fds_composto (
            id_fds, id_substancia, concentracao_min, concentracao_max
        ) VALUES (
            p_id_fds,
            v_id_substancia,
            NULLIF(v_composto ->> 'concentracao_min', '')::NUMERIC(5,2),
            NULLIF(v_composto ->> 'concentracao_max', '')::NUMERIC(5,2)
        );

        -- 4. não resolveu -> vira pendência de curadoria
        IF v_id_substancia IS NULL THEN
            INSERT INTO sinonimo_pendente (
                termo_bruto, cas_bruto, id_fds
            ) VALUES (
                COALESCE(v_nome_raw, '(sem nome)'),
                v_cas_raw,
                p_id_fds
            );
        END IF;
    END LOOP;

    -- ================================================================
    -- SEÇÃO 10 — incompatibilidades (opcional; hoje sempre ausente,
    -- parser só grava texto bruto, que fica preservado no raw_json)
    -- ================================================================
    IF jsonb_typeof(v_raw #> '{secoes,10,incompatibilidades}') = 'array' THEN
        FOR v_incompatibilidade IN
            SELECT jsonb_array_elements(v_raw #> '{secoes,10,incompatibilidades}')
        LOOP
            INSERT INTO fds_incompatibilidade (
                id_fds, substancia_reagente, descricao_risco, severidade
            ) VALUES (
                p_id_fds,
                v_incompatibilidade ->> 'substancia_reagente',
                v_incompatibilidade ->> 'descricao_risco',
                COALESCE(v_incompatibilidade ->> 'severidade', 'media')
            );
        END LOOP;
    END IF;

    -- ================================================================
    -- SEÇÃO 13 — descarte
    -- ================================================================
    FOR v_descarte IN
        SELECT jsonb_array_elements(
            COALESCE(v_raw #> '{secoes,13,descartes}', '[]'::jsonb)
        )
    LOOP
        INSERT INTO fds_descarte (
            id_fds, instrucao_descarte, tipo_residuo
        ) VALUES (
            p_id_fds,
            v_descarte ->> 'instrucao_descarte',
            COALESCE(v_descarte ->> 'tipo_residuo', 'quimico')
        );
    END LOOP;
END;
$$;

COMMENT ON FUNCTION fn_processar_fds_raw_json(INTEGER) IS 'Materializa fds.raw_json em fds_composto, fds_incompatibilidade e fds_descarte. Resolve cada composto por CAS, sinônimo normalizado e nome canônico; o que não resolver vira pendência em sinonimo_pendente. Idempotente.';
