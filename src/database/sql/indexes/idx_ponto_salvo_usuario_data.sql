CREATE INDEX IF NOT EXISTS idx_ponto_salvo_usuario_data ON ponto_salvo (id_usuario, criado_em DESC);

COMMENT ON INDEX idx_ponto_salvo_usuario_data IS 'Acelera a listagem dos pontos salvos de um usuário do mais recente para o mais antigo (buscar_pontos_salvos, Home).';
