CREATE INDEX IF NOT EXISTS idx_fds_produto_ativo ON fds (id_produto, ativo) WHERE ativo = TRUE;

COMMENT ON INDEX idx_fds_produto_ativo IS 'Índice parcial só das FDS ativas por produto, usado por fn_match_produtos e buscar_dados_fds.';
