CREATE INDEX IF NOT EXISTS idx_estante_produto_estante_data ON estante_produto (id_estante, data_adicionado);

COMMENT ON INDEX idx_estante_produto_estante_data IS 'Acelera a listagem da estante ordenada ou filtrada por data_adicionado (Recentes/Antigos).';
