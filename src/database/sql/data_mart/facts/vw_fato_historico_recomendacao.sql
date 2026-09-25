CREATE OR REPLACE VIEW vw_fato_historico_recomendacao AS
WITH base AS (
    SELECT
        hr.id AS id_fato,
        hr.id_produto,
        hr.id_usuario,
        hr.resultado,
        hr.data_consulta::date AS data
    FROM historico_recomendacao hr
),
ranking_produto AS (
    SELECT
        id_produto,
        COUNT(*) AS total_consultas,
        RANK() OVER (ORDER BY COUNT(*) DESC) AS ranking_produto_mais_consultado
    FROM base
    GROUP BY id_produto
),
running_total_diario AS (
    SELECT
        data,
        COUNT(*) AS consultas_no_dia,
        SUM(COUNT(*)) OVER (ORDER BY data) AS running_total_consultas
    FROM base
    GROUP BY data
)
SELECT
    b.id_fato,
    b.data,
    dp.id_produto,
    dp.nome_produto,
    dp.nome_marca,
    du.id_usuario,
    du.nivel_acesso,
    b.resultado,
    rp.total_consultas AS total_consultas_do_produto,
    rp.ranking_produto_mais_consultado,
    rtd.consultas_no_dia,
    rtd.running_total_consultas
FROM base b
JOIN dim_produto dp   ON dp.id_produto = b.id_produto
JOIN dim_usuario du   ON du.id_usuario = b.id_usuario
JOIN ranking_produto rp       ON rp.id_produto = b.id_produto
JOIN running_total_diario rtd ON rtd.data = b.data;
