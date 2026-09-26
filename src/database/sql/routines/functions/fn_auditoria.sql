CREATE OR REPLACE FUNCTION fn_auditoria()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO log_auditoria (tabela_afetada, operacao, dado_anterior, dado_novo, usuario_db)
    VALUES (
        TG_TABLE_NAME,
        TG_OP,
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN row_to_json(OLD)::jsonb ELSE NULL END,
        CASE WHEN TG_OP IN ('INSERT', 'UPDATE') THEN row_to_json(NEW)::jsonb ELSE NULL END,
        CURRENT_USER
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_auditoria() IS 'Função de trigger genérica de auditoria: grava em log_auditoria a tabela (TG_TABLE_NAME), a operação (TG_OP), OLD/NEW em JSONB e o CURRENT_USER.';
