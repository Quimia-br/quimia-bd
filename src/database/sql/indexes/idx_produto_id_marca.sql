CREATE INDEX IF NOT EXISTS idx_produto_id_marca ON produto (id_marca);

COMMENT ON INDEX idx_produto_id_marca IS 'Acelera a junção produto x marca (dim_produto).';
