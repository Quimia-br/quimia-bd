-- A FDS pode declarar incompatibilidade sem graduar sua severidade.
BEGIN;
DO $migration$
DECLARE
    definicao TEXT;
    antigo CONSTANT TEXT := $old$v_severidade := 'media';$old$;
    novo CONSTANT TEXT := $new$v_severidade := NULL;$new$;
BEGIN
    SELECT pg_get_functiondef('public.fn_processar_fds_raw_json(integer)'::regprocedure) INTO definicao;
    IF position(antigo IN definicao) > 0 THEN
        EXECUTE replace(definicao, antigo, novo);
    ELSIF position(novo IN definicao) = 0 THEN
        RAISE EXCEPTION 'Função de FDS diferente da versão esperada; migração cancelada.';
    END IF;
END;
$migration$;
COMMIT;
