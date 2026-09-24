CREATE OR REPLACE VIEW vw_fato_auditoria AS
SELECT
    tabela_afetada,
    operacao,
    alterado_em::date AS data,
    COUNT(*) AS total_operacoes
FROM log_auditoria
GROUP BY tabela_afetada, operacao, alterado_em::date;