DROP TRIGGER IF EXISTS TRIGGER trg_atualizar_ultima_sessao ON usuario_sessao_evento();
DROP TRIGGER IF EXISTS TRIGGER atualizar_ultima_sessao ON usuario_sessao_evento();

CREATE TRIGGER trg_atualizar_ultima_sessao
AFTER INSERT ON usuario_sessao_evento
FOR EACH ROW
EXECUTE FUNCTION fn_atualizar_ultima_sessao();