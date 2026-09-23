CREATE OR REPLACE VIEW dim_substancia AS
SELECT
    s.id AS id_substancia,
    s.nome_canonico,
    s.cas_numero,
    STRING_AGG(DISTINCT cq.nome, ', ' ORDER BY cq.nome) AS classes_quimicas
FROM substancia s
LEFT JOIN substancia_classe_quimica scq ON scq.id_substancia = s.id
LEFT JOIN classe_quimica cq ON cq.id = scq.id_classe_quimica
GROUP BY s.id, s.nome_canonico, s.cas_numero;