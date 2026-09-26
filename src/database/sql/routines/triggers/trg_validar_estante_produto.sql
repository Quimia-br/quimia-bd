DROP TRIGGER IF EXISTS trg_validar_estante_produto ON estante_produto;

CREATE TRIGGER trg_validar_estante_produto
BEFORE INSERT OR UPDATE ON estante_produto
FOR EACH ROW
EXECUTE FUNCTION fn_validar_estante_produto();

COMMENT ON TRIGGER trg_validar_estante_produto ON estante_produto IS 'Antes de gravar, garante que o produto entra numa estante do próprio usuário (fn_validar_estante_produto).';
