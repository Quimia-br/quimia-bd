-- Preserva as concentrações pequenas informadas em fichas técnicas.
BEGIN;

ALTER TABLE fds_composto
    ALTER COLUMN concentracao_min TYPE NUMERIC(12,8),
    ALTER COLUMN concentracao_max TYPE NUMERIC(12,8);

DO $migration$
DECLARE
    definicao TEXT;
    antigo CONSTANT TEXT := '::numeric(5,2)';
    novo CONSTANT TEXT := '::numeric(12,8)';
    ocorrencias INTEGER;
BEGIN
    SELECT pg_get_functiondef('public.fn_processar_fds_raw_json(integer)'::regprocedure)
      INTO definicao;
    -- pg_get_functiondef preserva a capitalização do corpo fornecido.
    ocorrencias := (length(lower(definicao)) - length(replace(lower(definicao), antigo, ''))) / length(antigo);
    IF ocorrencias = 2 THEN
        definicao := replace(replace(definicao, '::NUMERIC(5,2)', '::NUMERIC(12,8)'), antigo, novo);
        EXECUTE definicao;
    ELSIF ocorrencias <> 0 OR position(novo IN lower(definicao)) = 0 THEN
        RAISE EXCEPTION 'Função de FDS diferente da versão esperada; migração cancelada.';
    END IF;
END;
$migration$;

COMMIT;
