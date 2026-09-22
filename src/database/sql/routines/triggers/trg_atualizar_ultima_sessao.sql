DROP TRIGGER IF EXISTS trg_atualizar_ultima_sessao ON sessao_acesso;

CREATE TRIGGER trg_atualizar_ultima_sessao
AFTER INSERT ON sessao_acesso
FOR EACH ROW
EXECUTE FUNCTION fn_atualizar_ultima_sessao();