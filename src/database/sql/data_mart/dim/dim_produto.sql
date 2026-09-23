CREATE OR REPLACE VIEW dim_produto AS
SELECT
    p.id AS id_produto,
    p.nome AS nome_produto,
    p.tipo_produto,
    m.nome AS nome_marca,
    p.cod_barras
FROM produto p
JOIN marca m ON m.id = p.id_marca;