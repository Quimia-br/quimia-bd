ALTER TABLE produto DROP CONSTRAINT fk_produto_marca;
ALTER TABLE produto
ADD CONSTRAINT fk_produto_marca
FOREIGN KEY (id_marca)
REFERENCES marca(id)
ON DELETE CASCADE;

ALTER TABLE fds DROP CONSTRAINT fk_fds_produto;
ALTER TABLE fds
ADD CONSTRAINT fk_fds_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE fds_incompatibilidade DROP CONSTRAINT fk_incompatibilidade_fds;
ALTER TABLE fds_incompatibilidade
ADD CONSTRAINT fk_incompatibilidade_fds
FOREIGN KEY (id_fds)
REFERENCES fds(id)
ON DELETE CASCADE;

ALTER TABLE fds_composto DROP CONSTRAINT fk_composto_fds;
ALTER TABLE fds_composto
ADD CONSTRAINT fk_composto_fds
FOREIGN KEY (id_fds)
REFERENCES fds(id)
ON DELETE CASCADE;

ALTER TABLE fds_descarte DROP CONSTRAINT fk_descarte_fds;
ALTER TABLE fds_descarte
ADD CONSTRAINT fk_descarte_fds
FOREIGN KEY (id_fds)
REFERENCES fds(id)
ON DELETE CASCADE;

ALTER TABLE empresa_produto DROP CONSTRAINT fk_empresa_produto_empresa;
ALTER TABLE empresa_produto
ADD CONSTRAINT fk_empresa_produto_empresa
FOREIGN KEY (id_empresa)
REFERENCES empresa(id)
ON DELETE CASCADE;

ALTER TABLE empresa_produto DROP CONSTRAINT fk_empresa_produto_produto;
ALTER TABLE empresa_produto
ADD CONSTRAINT fk_empresa_produto_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE produto_superficie DROP CONSTRAINT fk_produto_superficie_produto;
ALTER TABLE produto_superficie
ADD CONSTRAINT fk_produto_superficie_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE produto_superficie DROP CONSTRAINT fk_produto_superficie_superficie;
ALTER TABLE produto_superficie
ADD CONSTRAINT fk_produto_superficie_superficie
FOREIGN KEY (id_superficie)
REFERENCES superficie(id)
ON DELETE CASCADE;

ALTER TABLE localizacao_usuario DROP CONSTRAINT fk_localizacao_usuario;
ALTER TABLE localizacao_usuario
ADD CONSTRAINT fk_localizacao_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id)
ON DELETE CASCADE;

ALTER TABLE estante DROP CONSTRAINT fk_estante_usuario;
ALTER TABLE estante
ADD CONSTRAINT fk_estante_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id)
ON DELETE CASCADE;

ALTER TABLE estante_produto DROP CONSTRAINT fk_estante_produto_produto;
ALTER TABLE estante_produto
ADD CONSTRAINT fk_estante_produto_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE estante_produto DROP CONSTRAINT fk_estante_produto_usuario;
ALTER TABLE estante_produto
ADD CONSTRAINT fk_estante_produto_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id)
ON DELETE CASCADE;

ALTER TABLE estante_produto DROP CONSTRAINT fk_estante_produto_estante;
ALTER TABLE estante_produto
ADD CONSTRAINT fk_estante_produto_estante
FOREIGN KEY (id_estante)
REFERENCES estante(id)
ON DELETE CASCADE;

ALTER TABLE historico_recomendacao DROP CONSTRAINT fk_hist_recomendacao_produto;
ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE historico_recomendacao DROP CONSTRAINT fk_hist_recomendacao_usuario;
ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id)
ON DELETE CASCADE;

ALTER TABLE historico_recomendacao DROP CONSTRAINT fk_hist_recomendacao_superficie;
ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_superficie
FOREIGN KEY (id_superficie)
REFERENCES superficie(id)
ON DELETE CASCADE;

ALTER TABLE ponto_parceiro DROP CONSTRAINT fk_ponto_parceiro_empresa;
ALTER TABLE ponto_parceiro
ADD CONSTRAINT fk_ponto_parceiro_empresa
FOREIGN KEY (id_empresa)
REFERENCES empresa(id)
ON DELETE CASCADE;