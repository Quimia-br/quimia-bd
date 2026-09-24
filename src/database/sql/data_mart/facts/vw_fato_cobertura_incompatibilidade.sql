CREATE OR REPLACE VIEW vw_cobertura_incompatibilidade AS
SELECT
    cq.nome AS classe_quimica,
    COUNT(DISTINCT ir.id) AS total_regras_envolvendo_classe
FROM classe_quimica cq
LEFT JOIN incompatibilidade_regra ir
    ON ir.id_classe_a = cq.id OR ir.id_classe_b = cq.id
GROUP BY cq.nome;