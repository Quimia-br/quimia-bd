DROP FUNCTION IF EXISTS buscar_pontos_salvos(UUID, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION buscar_pontos_salvos(
    p_id_usuario UUID,
    p_tipo       VARCHAR DEFAULT NULL,
    p_limite     INTEGER DEFAULT NULL
)
RETURNS TABLE (
    id_ponto    INTEGER,
    nome        VARCHAR(255),
    tipo        VARCHAR(50),
    cep         VARCHAR(9),
    estado      VARCHAR(2),
    bairro      VARCHAR(255),
    rua         VARCHAR(255),
    numero      INTEGER,
    complemento VARCHAR(50),
    latitude    NUMERIC(9,6),
    longitude   NUMERIC(9,6),
    criado_em   TIMESTAMP
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT pp.id, pp.nome, pp.tipo, pp.cep, pp.estado, pp.bairro, pp.rua,
           pp.numero, pp.complemento, pp.latitude, pp.longitude, ps.criado_em
      FROM ponto_salvo ps
      JOIN ponto_parceiro pp ON pp.id = ps.id_ponto
     WHERE ps.id_usuario = p_id_usuario
       AND (p_tipo IS NULL OR pp.tipo = p_tipo)
       AND COALESCE(pp.ativo, TRUE)
     ORDER BY ps.criado_em DESC, ps.id DESC
     LIMIT p_limite;
END;
$$;

COMMENT ON FUNCTION buscar_pontos_salvos(UUID, VARCHAR, INTEGER) IS 'Pontos salvos de um usuário (só pontos ativos), do mais recente ao mais antigo; p_tipo (compra/descarte) e p_limite são opcionais. A Home usa buscar_pontos_salvos(id, ''descarte'', 1): se o último for removido, devolve o anterior.';
