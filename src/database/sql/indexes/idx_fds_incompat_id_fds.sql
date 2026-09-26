CREATE INDEX IF NOT EXISTS idx_fds_incompat_id_fds ON fds_incompatibilidade (id_fds);

COMMENT ON INDEX idx_fds_incompat_id_fds IS 'Acelera a busca das incompatibilidades de uma FDS (buscar_incompatibilidades).';
