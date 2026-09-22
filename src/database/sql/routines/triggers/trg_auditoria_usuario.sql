DROP TRIGGER IF EXISTS trg_auditoria_usuario ON usuario;

CREATE TRIGGER trg_auditoria_usuario
AFTER INSERT OR UPDATE OR DELETE ON usuario
FOR EACH ROW
EXECUTE FUNCTION fn_auditoria();