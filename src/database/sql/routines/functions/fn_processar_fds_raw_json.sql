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
-- fds_incompatibilidade (seção 10) e fds_primeiro_socorro (seção 04)
-- também são populadas aqui; fn_match_produtos usa as incompatibilidades
-- resolvidas da FDS além das regras curadas de incompatibilidade_regra.
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
    v_socorro           JSONB;

    v_reagente_norm     TEXT;
    v_id_classe         INTEGER;
    v_severidade        TEXT;

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
    DELETE FROM fds_primeiro_socorro  WHERE id_fds = p_id_fds;

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
            id_fds, id_substancia, concentracao_min, concentracao_max, unidade_concentracao
        ) VALUES (
            p_id_fds,
            v_id_substancia,
            NULLIF(v_composto ->> 'concentracao_min', '')::NUMERIC(5,2),
            NULLIF(v_composto ->> 'concentracao_max', '')::NUMERIC(5,2),
            left(NULLIF(btrim(v_composto ->> 'unidade_concentracao'), ''), 20)
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
    -- SEÇÃO 10 — incompatibilidades (opcional)
    -- Resolve o reagente para substância (CAS ou nome/sinônimo) ou classe
    -- química (nome normalizado, '_' = espaço). O que não resolver fica
    -- só como texto (ex.: "Temperaturas altas") e não entra no match.
    -- ================================================================
    IF jsonb_typeof(v_raw #> '{secoes,10,incompatibilidades}') = 'array' THEN
        FOR v_incompatibilidade IN
            SELECT jsonb_array_elements(v_raw #> '{secoes,10,incompatibilidades}')
        LOOP
            v_id_substancia := NULL;
            v_id_classe     := NULL;
            v_cas_raw       := v_incompatibilidade ->> 'cas_numero';
            v_reagente_norm := lower(unaccent(btrim(v_incompatibilidade ->> 'substancia_reagente')));

            IF v_cas_raw IS NOT NULL THEN
                SELECT s.id INTO v_id_substancia
                FROM substancia s WHERE s.cas_numero = btrim(v_cas_raw);
            END IF;

            IF v_id_substancia IS NULL AND v_reagente_norm IS NOT NULL THEN
                SELECT ss.id_substancia INTO v_id_substancia
                FROM substancia_sinonimo ss
                WHERE ss.sinonimo_normalizado = v_reagente_norm;
            END IF;

            IF v_id_substancia IS NULL AND v_reagente_norm IS NOT NULL THEN
                SELECT s.id INTO v_id_substancia
                FROM substancia s
                WHERE lower(unaccent(btrim(s.nome_canonico))) = v_reagente_norm;
            END IF;

            IF v_id_substancia IS NULL AND v_reagente_norm IS NOT NULL THEN
                SELECT cq.id INTO v_id_classe
                FROM classe_quimica cq
                WHERE lower(unaccent(replace(cq.nome, '_', ' '))) = v_reagente_norm;
            END IF;

            v_severidade := lower(btrim(v_incompatibilidade ->> 'severidade'));
            IF v_severidade IS NULL OR v_severidade NOT IN ('baixa','media','alta','critica') THEN
                v_severidade := 'media';
            END IF;

            INSERT INTO fds_incompatibilidade (
                id_fds, id_substancia, id_classe_quimica,
                substancia_reagente, descricao_risco, severidade
            ) VALUES (
                p_id_fds,
                v_id_substancia,
                v_id_classe,
                left(v_incompatibilidade ->> 'substancia_reagente', 255),
                v_incompatibilidade ->> 'descricao_risco',
                v_severidade
            );
        END LOOP;
    END IF;

    -- ================================================================
    -- SEÇÃO 04 — primeiros socorros (rota fora do domínio é ignorada,
    -- para não derrubar o INSERT da FDS inteira)
    -- ================================================================
    FOR v_socorro IN
        SELECT jsonb_array_elements(
            COALESCE(v_raw #> '{secoes,04,primeiros_socorros}', v_raw #> '{secoes,04,primeiros_socorro}', '[]'::jsonb)
        )
    LOOP
        CONTINUE WHEN lower(v_socorro ->> 'rota_exposicao') IS NULL
                   OR lower(v_socorro ->> 'rota_exposicao') NOT IN ('inalacao','pele','olhos','ingestao');

        INSERT INTO fds_primeiro_socorro (
            id_fds, rota_exposicao, descricao, sintomas,
            tratamento_especial, atencao_medica_imediata
        ) VALUES (
            p_id_fds,
            lower(v_socorro ->> 'rota_exposicao'),
            v_socorro ->> 'descricao',
            v_socorro ->> 'sintomas',
            v_socorro ->> 'tratamento_especial',
            COALESCE((v_socorro ->> 'atencao_medica_imediata')::BOOLEAN, FALSE)
        );
    END LOOP;

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
