CREATE INDEX IF NOT EXISTS idx_fds_composto_id_fds ON fds_composto(id_fds);

COMMENT ON INDEX idx_fds_composto_id_fds IS 'Acelera a busca dos compostos de uma FDS (fn_match_produtos, vw_qualidade_resolucao_fds).';
