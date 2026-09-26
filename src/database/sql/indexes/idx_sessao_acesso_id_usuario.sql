CREATE INDEX IF NOT EXISTS idx_sessao_acesso_id_usuario ON sessao_acesso (id_usuario);

COMMENT ON INDEX idx_sessao_acesso_id_usuario IS 'Acelera a busca dos logins de um usuário.';
