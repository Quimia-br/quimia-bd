CREATE INDEX IF NOT EXISTS idx_fds_descarte_id_fds ON fds_descarte (id_fds);

COMMENT ON INDEX idx_fds_descarte_id_fds IS 'Acelera a busca das instruções de descarte de uma FDS.';
