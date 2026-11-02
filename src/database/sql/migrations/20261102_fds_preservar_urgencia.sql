-- Preserva o estado desconhecido informado pela FDS nas novas extrações.
-- A aplicação deve continuar aceitando booleano ausente ou nulo antes da
-- API passar a expor esse estado. As linhas históricas não são reinterpretadas.
BEGIN;

ALTER TABLE fds_primeiro_socorro
    ALTER COLUMN atencao_medica_imediata DROP NOT NULL,
    ALTER COLUMN atencao_medica_imediata DROP DEFAULT;

DO $migration$
DECLARE
    definicao TEXT;
    trecho_atual CONSTANT TEXT := 'COALESCE((v_socorro ->> ''atencao_medica_imediata'')::BOOLEAN, FALSE)';
    trecho_corrigido CONSTANT TEXT := '(v_socorro ->> ''atencao_medica_imediata'')::BOOLEAN';
BEGIN
    SELECT pg_get_functiondef('public.fn_processar_fds_raw_json(integer)'::regprocedure)
      INTO definicao;
    IF position(trecho_atual IN definicao) > 0 THEN
        EXECUTE replace(definicao, trecho_atual, trecho_corrigido);
    ELSIF position(trecho_corrigido IN definicao) = 0 THEN
        RAISE EXCEPTION 'Função de FDS diferente da versão esperada; migração cancelada.';
    END IF;
END;
$migration$;

COMMENT ON COLUMN fds_primeiro_socorro.atencao_medica_imediata IS
    'Indica se a FDS exige atendimento médico imediato; nulo quando não informado.';

COMMIT;
