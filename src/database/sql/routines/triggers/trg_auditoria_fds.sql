DROP TRIGGER IF EXISTS trg_auditoria_fds ON fds;

CREATE TRIGGER trg_auditoria_fds
AFTER INSERT OR UPDATE OR DELETE ON fds
FOR EACH ROW
EXECUTE FUNCTION fn_auditoria();

COMMENT ON TRIGGER trg_auditoria_fds ON fds IS 'Audita INSERT, UPDATE e DELETE em fds no log_auditoria.';
