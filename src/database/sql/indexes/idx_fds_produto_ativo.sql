CREATE INDEX IF NOT EXISTS idx_fds_produto_ativo ON fds (id_produto, ativo) WHERE ativo = TRUE;
