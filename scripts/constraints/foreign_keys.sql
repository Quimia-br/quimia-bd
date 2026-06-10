-- ==========================================
-- PRODUTO -> MARCA
-- ==========================================

ALTER TABLE produto
ADD CONSTRAINT fk_produto_marca
FOREIGN KEY (id_marca)
REFERENCES marca(id);

-- ==========================================
-- FDS -> PRODUTO
-- ==========================================

ALTER TABLE fds
ADD CONSTRAINT fk_fds_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id);

-- ==========================================
-- FDS_INCOMPATIBILIDADE -> FDS
-- ==========================================

ALTER TABLE fds_incompatibilidade
ADD CONSTRAINT fk_incompatibilidade_fds
FOREIGN KEY (id_fds)
REFERENCES fds(id);

-- ==========================================
-- FDS_COMPOSTO -> FDS
-- ==========================================

ALTER TABLE fds_composto
ADD CONSTRAINT fk_composto_fds
FOREIGN KEY (id_fds)
REFERENCES fds(id);

-- ==========================================
-- FDS_DESCARTE -> FDS
-- ==========================================

ALTER TABLE fds_descarte
ADD CONSTRAINT fk_descarte_fds
FOREIGN KEY (id_fds)
REFERENCES fds(id);

-- ==========================================
-- EMPRESA_PRODUTO
-- ==========================================

ALTER TABLE empresa_produto
ADD CONSTRAINT fk_empresa_produto_empresa
FOREIGN KEY (id_empresa)
REFERENCES empresa(id);

ALTER TABLE empresa_produto
ADD CONSTRAINT fk_empresa_produto_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id);

ALTER TABLE empresa_produto
ADD CONSTRAINT un_empresa_produto
UNIQUE (id_empresa, id_produto);

-- ==========================================
-- PRODUTO_SUPERFICIE
-- ==========================================

ALTER TABLE produto_superficie
ADD CONSTRAINT fk_produto_superficie_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id);

ALTER TABLE produto_superficie
ADD CONSTRAINT fk_produto_superficie_superficie
FOREIGN KEY (id_superficie)
REFERENCES superficie(id);

ALTER TABLE produto_superficie
ADD CONSTRAINT un_produto_superficie
UNIQUE (id_produto, id_superficie);

-- ==========================================
-- USER_PRODUTO
-- ==========================================

ALTER TABLE user_produto
ADD CONSTRAINT fk_user_produto_usuario
FOREIGN KEY (id_user)
REFERENCES usuario(id);

ALTER TABLE user_produto
ADD CONSTRAINT fk_user_produto_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id);

-- ==========================================
-- LOCALIZACAO_USUARIO
-- ==========================================

ALTER TABLE localizacao_usuario
ADD CONSTRAINT fk_localizacao_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id);

-- ==========================================
-- ESTANTE
-- ==========================================

ALTER TABLE estante
ADD CONSTRAINT fk_estante_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id);

-- ==========================================
-- ESTANTE_PRODUTO
-- ==========================================

ALTER TABLE estante_produto
ADD CONSTRAINT fk_estante_produto_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id);

ALTER TABLE estante_produto
ADD CONSTRAINT fk_estante_produto_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id);

ALTER TABLE estante_produto
ADD CONSTRAINT fk_estante_produto_estante
FOREIGN KEY (id_estante)
REFERENCES estante(id);

ALTER TABLE estante_produto
ADD CONSTRAINT un_estante_produto
UNIQUE (id_estante, id_produto);

-- ==========================================
-- HISTORICO_RECOMENDACAO
-- ==========================================

ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id);

ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id);

ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_user_produto
FOREIGN KEY (id_usuario_produto)
REFERENCES user_produto(id);

ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_superficie
FOREIGN KEY (id_superficie)
REFERENCES superficie(id);