CREATE INDEX IF NOT EXISTS idx_log_auditoria_tabela_data ON log_auditoria (tabela_afetada, alterado_em);

COMMENT ON INDEX idx_log_auditoria_tabela_data IS 'Acelera consultas de auditoria por tabela e período (vw_fato_auditoria).';
