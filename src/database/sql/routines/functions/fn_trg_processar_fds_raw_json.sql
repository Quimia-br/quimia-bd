CREATE OR REPLACE FUNCTION fn_trg_processar_fds_raw_json()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM fn_processar_fds_raw_json(NEW.id);
    RETURN NEW;
END;
$$;