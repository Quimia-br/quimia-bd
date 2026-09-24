CREATE OR REPLACE VIEW vw_qualidade_resolucao_fds AS
SELECT
    f.id AS id_fds,
    p.nome AS nome_produto,
    COUNT(fc.id) AS total_compostos,
    COUNT(fc.id_substancia) AS compostos_resolvidos,
    COUNT(fc.id) - COUNT(fc.id_substancia) AS compostos_pendentes,
    ROUND(
        COUNT(fc.id_substancia)::numeric / NULLIF(COUNT(fc.id), 0) * 100, 1
    ) AS pct_resolucao
FROM fds f
JOIN produto p ON p.id = f.id_produto
LEFT JOIN fds_composto fc ON fc.id_fds = f.id
GROUP BY f.id, p.nome;