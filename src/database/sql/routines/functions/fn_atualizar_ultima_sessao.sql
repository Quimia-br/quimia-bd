DROP FUNCTION IF EXISTS fn_atualizar_ultima_sessao();
DROP FUNCTION IF EXISTS atualizar_ultima_sessao();

CREATE OR REPLACE FUNCTION fn_atualizar_ultima_sessao()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE usuario
        SET ultima_sessao = NEW.ocorreu_em
        WHERE id = NEW.id_usuario
            AND (ultima_sessao IS NULL OR ultima_sessao < NEW.ocorreu_em);
            RETURN NEW;
        END;
        $$;

COMMENT ON FUNCTION fn_atualizar_ultima_sessao() IS 'Função de trigger: copia o horário do login (sessao_acesso.ocorreu_em) para usuario.ultima_sessao, só se for mais recente.';
