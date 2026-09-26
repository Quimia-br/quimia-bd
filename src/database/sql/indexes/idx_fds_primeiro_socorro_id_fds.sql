CREATE INDEX IF NOT EXISTS idx_fds_primeiro_socorro_id_fds ON fds_primeiro_socorro (id_fds);

COMMENT ON INDEX idx_fds_primeiro_socorro_id_fds IS 'Acelera a busca dos primeiros socorros de uma FDS.';
