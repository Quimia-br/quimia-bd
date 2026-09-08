ALTER TABLE produto DROP CONSTRAINT IF EXISTS fk_produto_marca;
ALTER TABLE produto
ADD CONSTRAINT fk_produto_marca
FOREIGN KEY (id_marca) REFERENCES marca(id)
ON DELETE SET NULL;

ALTER TABLE fds DROP CONSTRAINT IF EXISTS fk_fds_produto;
ALTER TABLE fds
ADD CONSTRAINT fk_fds_produto
FOREIGN KEY (id_produto) REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE fds_incompatibilidade DROP CONSTRAINT IF EXISTS fk_incompatibilidade_fds;
ALTER TABLE fds_incompatibilidade
ADD CONSTRAINT fk_incompatibilidade_fds
FOREIGN KEY (id_fds) REFERENCES fds(id)
ON DELETE CASCADE;

ALTER TABLE fds_incompatibilidade DROP CONSTRAINT IF EXISTS fk_substancia;
ALTER TABLE fds_incompatibilidade
ADD CONSTRAINT fk_substancia;
FOREIGN KEY (id_substancia) REFERENCES substancia(id)
ON DELETE CASCADE;

ALTER TABLE fds_incompatibilidade DROP CONSTRAINT IF EXISTS fk_classe_quimica;
ALTER TABLE fds_incompatibilidade
ADD CONSTRAINT fk_classe_quimica;
FOREIGN KEY (id_classe_quimica) REFERENCES classe_quimica(id)
ON DELETE CASCADE;



ALTER TABLE fds_composto DROP CONSTRAINT IF EXISTS fk_composto_fds;
ALTER TABLE fds_composto
ADD CONSTRAINT fk_composto_fds
FOREIGN KEY (id_fds) REFERENCES fds(id)
ON DELETE CASCADE;

ALTER TABLE fds_composto DROP CONSTRAINT IF EXISTS fk_fds_composto_substancia;
ALTER TABLE fds_composto
ADD CONSTRAINT fk_fds_composto_substancia
FOREIGN KEY (id_substancia) REFERENCES substancia(id)
ON DELETE SET NULL;

ALTER TABLE fds_descarte DROP CONSTRAINT IF EXISTS fk_descarte_fds;
ALTER TABLE fds_descarte
ADD CONSTRAINT fk_descarte_fds
FOREIGN KEY (id_fds) REFERENCES fds(id)
ON DELETE CASCADE;

ALTER TABLE substancia_sinonimo DROP CONSTRAINT IF EXISTS fk_sinonimo_substancia;
ALTER TABLE substancia_sinonimo
ADD CONSTRAINT fk_sinonimo_substancia
FOREIGN KEY (id_substancia) REFERENCES substancia(id)
ON DELETE CASCADE;

ALTER TABLE substancia_classe_quimica DROP CONSTRAINT IF EXISTS fk_substancia_classe_substancia;
ALTER TABLE substancia_classe_quimica
ADD CONSTRAINT fk_substancia_classe_substancia
FOREIGN KEY (id_substancia) REFERENCES substancia(id)
ON DELETE CASCADE;

ALTER TABLE substancia_classe_quimica DROP CONSTRAINT IF EXISTS fk_substancia_classe_classe;
ALTER TABLE substancia_classe_quimica
ADD CONSTRAINT fk_substancia_classe_classe
FOREIGN KEY (id_classe_quimica) REFERENCES classe_quimica(id)
ON DELETE CASCADE;

ALTER TABLE incompatibilidade_regra DROP CONSTRAINT IF EXISTS fk_regra_substancia_a;
ALTER TABLE incompatibilidade_regra
ADD CONSTRAINT fk_regra_substancia_a
FOREIGN KEY (id_substancia_a) REFERENCES substancia(id)
ON DELETE CASCADE;

ALTER TABLE incompatibilidade_regra DROP CONSTRAINT IF EXISTS fk_regra_classe_a;
ALTER TABLE incompatibilidade_regra
ADD CONSTRAINT fk_regra_classe_a
FOREIGN KEY (id_classe_a) REFERENCES classe_quimica(id)
ON DELETE CASCADE;

ALTER TABLE incompatibilidade_regra DROP CONSTRAINT IF EXISTS fk_regra_substancia_b;
ALTER TABLE incompatibilidade_regra
ADD CONSTRAINT fk_regra_substancia_b
FOREIGN KEY (id_substancia_b) REFERENCES substancia(id)
ON DELETE CASCADE;

ALTER TABLE incompatibilidade_regra DROP CONSTRAINT IF EXISTS fk_regra_classe_b;
ALTER TABLE incompatibilidade_regra
ADD CONSTRAINT fk_regra_classe_b
FOREIGN KEY (id_classe_b) REFERENCES classe_quimica(id)
ON DELETE CASCADE;

ALTER TABLE sinonimo_pendente DROP CONSTRAINT IF EXISTS fk_sinonimo_pendente_fds;
ALTER TABLE sinonimo_pendente
ADD CONSTRAINT fk_sinonimo_pendente_fds
FOREIGN KEY (id_fds) REFERENCES fds(id)
ON DELETE CASCADE;

ALTER TABLE sinonimo_pendente DROP CONSTRAINT IF EXISTS fk_sinonimo_pendente_substancia;
ALTER TABLE sinonimo_pendente
ADD CONSTRAINT fk_sinonimo_pendente_substancia
FOREIGN KEY (id_substancia_resolvida) REFERENCES substancia(id)
ON DELETE SET NULL;

-- empresa / produto / superfície

ALTER TABLE empresa_produto DROP CONSTRAINT IF EXISTS fk_empresa_produto_empresa;
ALTER TABLE empresa_produto
ADD CONSTRAINT fk_empresa_produto_empresa
FOREIGN KEY (id_empresa) REFERENCES empresa(id)
ON DELETE CASCADE;

ALTER TABLE empresa_produto DROP CONSTRAINT IF EXISTS fk_empresa_produto_produto;
ALTER TABLE empresa_produto
ADD CONSTRAINT fk_empresa_produto_produto
FOREIGN KEY (id_produto) REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE produto_superficie DROP CONSTRAINT IF EXISTS fk_produto_superficie_produto;
ALTER TABLE produto_superficie
ADD CONSTRAINT fk_produto_superficie_produto
FOREIGN KEY (id_produto) REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE produto_superficie DROP CONSTRAINT IF EXISTS fk_produto_superficie_superficie;
ALTER TABLE produto_superficie
ADD CONSTRAINT fk_produto_superficie_superficie
FOREIGN KEY (id_superficie) REFERENCES superficie(id)
ON DELETE CASCADE;

-- usuário / localização / estante / histórico

ALTER TABLE localizacao_usuario DROP CONSTRAINT IF EXISTS fk_localizacao_usuario;
ALTER TABLE localizacao_usuario
ADD CONSTRAINT fk_localizacao_usuario
FOREIGN KEY (id_usuario) REFERENCES usuario(id)
ON DELETE CASCADE;

ALTER TABLE estante DROP CONSTRAINT IF EXISTS fk_estante_usuario;
ALTER TABLE estante
ADD CONSTRAINT fk_estante_usuario
FOREIGN KEY (id_usuario) REFERENCES usuario(id)
ON DELETE CASCADE;

ALTER TABLE estante_produto DROP CONSTRAINT IF EXISTS fk_estante_produto_produto;
ALTER TABLE estante_produto
ADD CONSTRAINT fk_estante_produto_produto
FOREIGN KEY (id_produto) REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE estante_produto DROP CONSTRAINT IF EXISTS fk_estante_produto_usuario;
ALTER TABLE estante_produto
ADD CONSTRAINT fk_estante_produto_usuario
FOREIGN KEY (id_usuario) REFERENCES usuario(id)
ON DELETE CASCADE;

ALTER TABLE estante_produto DROP CONSTRAINT IF EXISTS fk_estante_produto_estante;
ALTER TABLE estante_produto
ADD CONSTRAINT fk_estante_produto_estante
FOREIGN KEY (id_estante) REFERENCES estante(id)
ON DELETE CASCADE;

ALTER TABLE historico_recomendacao DROP CONSTRAINT IF EXISTS fk_hist_recomendacao_produto;
ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_produto
FOREIGN KEY (id_produto) REFERENCES produto(id)
ON DELETE CASCADE;

ALTER TABLE historico_recomendacao DROP CONSTRAINT IF EXISTS fk_hist_recomendacao_usuario;
ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_usuario
FOREIGN KEY (id_usuario) REFERENCES usuario(id)
ON DELETE CASCADE;

ALTER TABLE historico_recomendacao DROP CONSTRAINT IF EXISTS fk_hist_recomendacao_superficie;
ALTER TABLE historico_recomendacao
ADD CONSTRAINT fk_hist_recomendacao_superficie
FOREIGN KEY (id_superficie) REFERENCES superficie(id)
ON DELETE SET NULL;

ALTER TABLE ponto_parceiro DROP CONSTRAINT IF EXISTS fk_ponto_parceiro_empresa;
ALTER TABLE ponto_parceiro
ADD CONSTRAINT fk_ponto_parceiro_empresa
FOREIGN KEY (id_empresa) REFERENCES empresa(id)
ON DELETE CASCADE;
