DROP PROCEDURE IF EXISTS guardar_produto_estante(UUID, INTEGER);

CREATE OR REPLACE PROCEDURE guardar_produto_estante(
    p_id_usuario UUID,
    p_id_produto INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO estante (id_usuario, nome)
    VALUES (p_id_usuario, 'Minha estante')
    ON CONFLICT (id_usuario) DO NOTHING;

    INSERT INTO estante_produto (id_produto, id_usuario, id_estante)
    SELECT p_id_produto, p_id_usuario, e.id
      FROM estante e
     WHERE e.id_usuario = p_id_usuario
    ON CONFLICT (id_estante, id_produto) DO NOTHING;
END;
$$;

COMMENT ON PROCEDURE guardar_produto_estante(UUID, INTEGER) IS 'Ação "Guardar": cria a estante padrão do usuário se ainda não existir e guarda o produto nela (idempotente).';
