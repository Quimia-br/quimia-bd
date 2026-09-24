CREATE OR REPLACE VIEW vw_fato_historico_match AS
SELECT
    hm.id AS id_fato,
    hm.data_consulta::date AS data,
    dpa.id_produto  AS id_produto_a,
    dpa.nome_produto AS nome_produto_a,
    dpb.id_produto  AS id_produto_b,
    dpb.nome_produto AS nome_produto_b,
    du.id_usuario,
    hm.resultado,
    hm.severidade,
    hm.descricao_risco,
    COUNT(*) OVER (
        PARTITION BY hm.resultado
        ORDER BY hm.data_consulta
    ) AS running_total_por_resultado
FROM historico_match hm
JOIN dim_produto dpa ON dpa.id_produto = hm.id_produto_a
JOIN dim_produto dpb ON dpb.id_produto = hm.id_produto_b
JOIN dim_usuario du  ON du.id_usuario = hm.id_usuario;