--vw_fato_auditoria — volume de alterações em tabelas sensíveis ao longo do tempo, 
--útil pra mostrar que a trilha de auditoria está ativa e funcionando


CREATE OR REPLACE VIEW vw_fato_auditoria AS
SELECT
    tabela_afetada,
    operacao,
    alterado_em::date AS data,
    COUNT(*) AS total_operacoes
FROM log_auditoria
GROUP BY tabela_afetada, operacao, alterado_em::date;