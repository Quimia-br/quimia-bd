CREATE OR REPLACE VIEW vw_fato_adocao_estante AS
SELECT
    e.id_usuario,
    COUNT(DISTINCT e.id) AS total_estantes,
    COUNT(ep.id_produto) AS total_produtos_organizados
FROM estante e
LEFT JOIN estante_produto ep ON ep.id_estante = e.id
GROUP BY e.id_usuario;