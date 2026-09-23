CREATE OR REPLACE VIEW dim_superficie AS
SELECT id AS id_superficie, nome AS nome_superficie,
descricao AS descricao_superficie
FROM superficie;