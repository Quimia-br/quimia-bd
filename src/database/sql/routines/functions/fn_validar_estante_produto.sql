DROP FUNCTION IF EXISTS fn_validar_estante_produto();
DROP FUNCTION IF EXISTS validar_estante_produto();

CREATE OR REPLACE FUNCTION fn_validar_estante_produto()
RETURNS TRIGGER AS $$
DECLARE
    v_id_usuario_estante UUID;
BEGIN
    SELECT e.id_usuario
      INTO v_id_usuario_estante
      FROM estante e
     WHERE e.id = NEW.id_estante;

    IF v_id_usuario_estante IS NULL THEN
        RAISE EXCEPTION 'Estante % não encontrada.', NEW.id_estante;
    END IF;

    IF NEW.id_usuario IS NULL THEN
        RAISE EXCEPTION 'id_usuario é obrigatório em estante_produto.';
    END IF;

    IF NEW.id_usuario <> v_id_usuario_estante THEN
        RAISE EXCEPTION
            'Usuário % não é dono da estante % (dono: %).',
            NEW.id_usuario, NEW.id_estante, v_id_usuario_estante;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_validar_estante_produto() IS 'Função de trigger que garante que o produto só entre numa estante do mesmo usuário (estante_produto.id_usuario = estante.id_usuario).';
