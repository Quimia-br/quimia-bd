DROP TRIGGER IF EXISTS trg_auditoria_usuario ON usuario;

CREATE TRIGGER trg_auditoria_usuario
AFTER INSERT OR UPDATE OR DELETE ON usuario
FOR EACH ROW
EXECUTE FUNCTION fn_auditoria();

COMMENT ON TRIGGER trg_auditoria_usuario ON usuario IS 'Audita INSERT, UPDATE e DELETE em usuario no log_auditoria.';
