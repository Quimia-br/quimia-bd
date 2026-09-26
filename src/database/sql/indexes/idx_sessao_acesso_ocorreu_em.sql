CREATE INDEX IF NOT EXISTS idx_sessao_acesso_ocorreu_em ON sessao_acesso (ocorreu_em);

COMMENT ON INDEX idx_sessao_acesso_ocorreu_em IS 'Acelera o cálculo do DAU por dia (vw_dau, vw_fato_sessao_acesso).';
