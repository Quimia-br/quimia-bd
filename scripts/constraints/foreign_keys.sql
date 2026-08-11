ALTER TABLE produto
ADD CONSTRAINT fk_produto_marca
FOREIGN KEY (id_marca)
REFERENCES marca(id);


ALTER TABLE fds
ADD CONSTRAINT fk_fds_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id);


ALTER TABLE fds_incompatibilidade
ADD CONSTRAINT fk_incompatibilidade_fds
FOREIGN KEY (id_fds)
REFERENCES fds(id);


ALTER TABLE fds_composto
ADD CONSTRAINT fk_composto_fds
FOREIGN KEY (id_fds)
REFERENCES fds(id);


ALTER TABLE fds_descarte
ADD CONSTRAINT fk_descarte_fds
FOREIGN KEY (id_fds)
REFERENCES fds(id);


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


ALTER TABLE localizacao_usuario
ADD CONSTRAINT fk_localizacao_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id);


ALTER TABLE estante
ADD CONSTRAINT fk_estante_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id);


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


ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_produto
FOREIGN KEY (id_produto)
REFERENCES produto(id);

ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_usuario
FOREIGN KEY (id_usuario)
REFERENCES usuario(id);

ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_superficie
FOREIGN KEY (id_superficie)
REFERENCES superficie(id);

ALTER TABLE ponto_parceiro
ADD COLUMN id_empresa INTEGER;

ALTER TABLE ponto_parceiro
ADD CONSTRAINT fk_ponto_parceiro_empresa
FOREIGN KEY (id_empresa) REFERENCES empresa(id);