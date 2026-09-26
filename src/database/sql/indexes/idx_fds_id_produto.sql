CREATE INDEX IF NOT EXISTS idx_fds_id_produto ON fds (id_produto);

COMMENT ON INDEX idx_fds_id_produto IS 'Acelera a busca das FDS de um produto.';
