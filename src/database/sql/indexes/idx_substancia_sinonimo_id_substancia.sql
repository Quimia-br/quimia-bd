CREATE INDEX IF NOT EXISTS idx_substancia_sinonimo_id_substancia ON substancia_sinonimo (id_substancia);

COMMENT ON INDEX idx_substancia_sinonimo_id_substancia IS 'Acelera a busca dos sinônimos de uma substância.';
