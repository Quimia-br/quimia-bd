-- Sinaliza que a FDS declara apenas parte dos ingredientes. A linha sem
-- substância identificada mantém avaliações sem evidência como não avaliadas.
BEGIN;
DO $migration$
DECLARE
    definicao TEXT;
    ancora CONSTANT TEXT := E'    -- ================================================================\n    -- SEÇÃO 10';
    marcador CONSTANT TEXT := 'marcador de composição parcial da FDS';
    insercao CONSTANT TEXT := $sql$
    -- marcador de composição parcial da FDS
    IF v_raw #>> '{secoes,03,composicao_parcial}' = 'true' THEN
        INSERT INTO fds_composto (id_fds, id_substancia, concentracao_min, concentracao_max, unidade_concentracao)
        VALUES (p_id_fds, NULL, NULL, NULL, NULL);
    END IF;

$sql$;
BEGIN
    SELECT pg_get_functiondef('public.fn_processar_fds_raw_json(integer)'::regprocedure) INTO definicao;
    IF position(marcador IN definicao) = 0 THEN
        IF position(ancora IN definicao) = 0 THEN
            RAISE EXCEPTION 'Função de FDS diferente da versão esperada; migração cancelada.';
        END IF;
        EXECUTE replace(definicao, ancora, insercao || ancora);
    END IF;
END;
$migration$;
COMMIT;
