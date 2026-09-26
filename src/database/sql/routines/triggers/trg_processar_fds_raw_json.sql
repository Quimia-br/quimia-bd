DROP TRIGGER IF EXISTS trg_processar_fds_raw_json ON fds;
DROP TRIGGER IF EXISTS processar_fds_raw_json ON fds;

CREATE TRIGGER trg_processar_fds_raw_json
AFTER INSERT OR UPDATE OF raw_json ON fds
FOR EACH ROW
EXECUTE FUNCTION fn_trg_processar_fds_raw_json();

COMMENT ON TRIGGER trg_processar_fds_raw_json ON fds IS 'Reprocessa as tabelas fds_* quando uma FDS é inserida ou quando raw_json muda.';
