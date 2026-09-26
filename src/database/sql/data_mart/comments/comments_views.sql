-- =====================================================================
-- Catálogo de Dados — descrições das views do Data Mart
-- Executado no fim do setup_data.py, depois de criadas as views.
-- =====================================================================

-- Dimensões -----------------------------------------------------------
COMMENT ON VIEW dim_tempo IS
'Dimensão calendário: um dia por linha, da primeira consulta registrada até hoje.';
COMMENT ON COLUMN dim_tempo.data IS 'Dia do calendário (chave da dimensão).';
COMMENT ON COLUMN dim_tempo.ano IS 'Ano do dia.';
COMMENT ON COLUMN dim_tempo.mes IS 'Mês do dia (1 a 12).';
COMMENT ON COLUMN dim_tempo.dia IS 'Dia do mês.';
COMMENT ON COLUMN dim_tempo.dia_semana IS 'Nome do dia da semana.';
COMMENT ON COLUMN dim_tempo.trimestre IS 'Trimestre do ano (1 a 4).';
COMMENT ON COLUMN dim_tempo.fim_de_semana IS 'Indica sábado ou domingo.';

COMMENT ON VIEW dim_produto IS
'Dimensão de produtos com o nome da marca desnormalizado.';
COMMENT ON COLUMN dim_produto.id_produto IS 'Identificador do produto.';
COMMENT ON COLUMN dim_produto.nome_produto IS 'Nome comercial do produto.';
COMMENT ON COLUMN dim_produto.tipo_produto IS 'Categoria do produto.';
COMMENT ON COLUMN dim_produto.nome_marca IS 'Nome da marca fabricante.';
COMMENT ON COLUMN dim_produto.cod_barras IS 'Código de barras (EAN).';

COMMENT ON VIEW dim_usuario IS
'Dimensão de usuários sem nome nem e-mail, de propósito (LGPD); expõe apenas perfil e região.';
COMMENT ON COLUMN dim_usuario.id_usuario IS 'Identificador UUID do usuário (pseudônimo, sem dado identificável).';
COMMENT ON COLUMN dim_usuario.nivel_acesso IS 'Perfil de acesso: usuario, empresa ou admin.';
COMMENT ON COLUMN dim_usuario.estado IS 'UF do usuário.';
COMMENT ON COLUMN dim_usuario.bairro IS 'Bairro do usuário.';

COMMENT ON VIEW dim_substancia IS
'Dimensão de substâncias com suas classes químicas concatenadas.';
COMMENT ON COLUMN dim_substancia.id_substancia IS 'Identificador da substância.';
COMMENT ON COLUMN dim_substancia.nome_canonico IS 'Nome padrão da substância.';
COMMENT ON COLUMN dim_substancia.cas_numero IS 'Número CAS.';
COMMENT ON COLUMN dim_substancia.classes_quimicas IS 'Classes químicas da substância, separadas por vírgula.';

COMMENT ON VIEW dim_localizacao IS
'Dimensão geográfica (estado e bairro) de usuários e pontos parceiros, sem endereço completo.';
COMMENT ON COLUMN dim_localizacao.estado IS 'UF.';
COMMENT ON COLUMN dim_localizacao.bairro IS 'Bairro.';

-- Fatos ---------------------------------------------------------------
COMMENT ON VIEW vw_fato_historico_recomendacao IS
'Fato de consultas de produto, com ranking de produtos mais consultados e total acumulado diário (CTE + window function).';
COMMENT ON COLUMN vw_fato_historico_recomendacao.id_fato IS 'Identificador da consulta de origem.';
COMMENT ON COLUMN vw_fato_historico_recomendacao.data IS 'Dia da consulta (liga com dim_tempo).';
COMMENT ON COLUMN vw_fato_historico_recomendacao.id_produto IS 'Produto consultado (liga com dim_produto).';
COMMENT ON COLUMN vw_fato_historico_recomendacao.nome_produto IS 'Nome do produto consultado.';
COMMENT ON COLUMN vw_fato_historico_recomendacao.nome_marca IS 'Marca do produto consultado.';
COMMENT ON COLUMN vw_fato_historico_recomendacao.id_usuario IS 'Usuário que consultou (liga com dim_usuario).';
COMMENT ON COLUMN vw_fato_historico_recomendacao.nivel_acesso IS 'Perfil do usuário que consultou.';
COMMENT ON COLUMN vw_fato_historico_recomendacao.resultado IS 'Resultado da recomendação.';
COMMENT ON COLUMN vw_fato_historico_recomendacao.total_consultas_do_produto IS 'Total de consultas do produto em todo o histórico.';
COMMENT ON COLUMN vw_fato_historico_recomendacao.ranking_produto_mais_consultado IS 'Posição do produto no ranking de mais consultados (RANK).';
COMMENT ON COLUMN vw_fato_historico_recomendacao.consultas_no_dia IS 'Total de consultas no dia.';
COMMENT ON COLUMN vw_fato_historico_recomendacao.running_total_consultas IS 'Total acumulado de consultas até o dia.';

COMMENT ON VIEW vw_fato_historico_match IS
'Fato de comparações produto x produto, com total acumulado por resultado (window function).';
COMMENT ON COLUMN vw_fato_historico_match.id_fato IS 'Identificador da comparação de origem.';
COMMENT ON COLUMN vw_fato_historico_match.data IS 'Dia da comparação.';
COMMENT ON COLUMN vw_fato_historico_match.id_produto_a IS 'Produto de menor id do par.';
COMMENT ON COLUMN vw_fato_historico_match.nome_produto_a IS 'Nome do produto A.';
COMMENT ON COLUMN vw_fato_historico_match.id_produto_b IS 'Produto de maior id do par.';
COMMENT ON COLUMN vw_fato_historico_match.nome_produto_b IS 'Nome do produto B.';
COMMENT ON COLUMN vw_fato_historico_match.id_usuario IS 'Usuário que comparou.';
COMMENT ON COLUMN vw_fato_historico_match.resultado IS 'Veredito: compativel, incompativel ou nao_avaliado.';
COMMENT ON COLUMN vw_fato_historico_match.severidade IS 'Gravidade da regra disparada.';
COMMENT ON COLUMN vw_fato_historico_match.descricao_risco IS 'Risco mostrado ao usuário.';
COMMENT ON COLUMN vw_fato_historico_match.running_total_por_resultado IS 'Total acumulado de comparações com o mesmo resultado até a data.';

COMMENT ON VIEW vw_fato_auditoria IS
'Volume diário de operações auditadas por tabela e tipo de operação.';
COMMENT ON COLUMN vw_fato_auditoria.tabela_afetada IS 'Tabela auditada.';
COMMENT ON COLUMN vw_fato_auditoria.operacao IS 'INSERT, UPDATE ou DELETE.';
COMMENT ON COLUMN vw_fato_auditoria.data IS 'Dia das operações.';
COMMENT ON COLUMN vw_fato_auditoria.total_operacoes IS 'Quantidade de operações no dia.';

COMMENT ON VIEW vw_dau IS 'Quantidade de usuários distintos ativos por dia, calculada a partir de sessao_acesso.';
COMMENT ON COLUMN vw_dau.data IS 'Dia de referência.';
COMMENT ON COLUMN vw_dau.usuarios_ativos IS 'Usuários distintos que fizeram login no dia.';

COMMENT ON VIEW vw_cobertura_incompatibilidade IS
'Quantidade de regras de incompatibilidade que envolvem cada classe química; aponta lacunas de curadoria.';
COMMENT ON COLUMN vw_cobertura_incompatibilidade.classe_quimica IS 'Nome da classe química.';
COMMENT ON COLUMN vw_cobertura_incompatibilidade.total_regras_envolvendo_classe IS 'Regras em que a classe aparece em qualquer lado.';

COMMENT ON VIEW vw_fato_sessao_acesso IS
'Fato de logins, com a quantidade de sessões do dia (window function).';
COMMENT ON COLUMN vw_fato_sessao_acesso.data IS 'Dia do login.';
COMMENT ON COLUMN vw_fato_sessao_acesso.id_usuario IS 'Usuário que fez login.';
COMMENT ON COLUMN vw_fato_sessao_acesso.sessoes_no_dia IS 'Total de logins no mesmo dia.';

COMMENT ON VIEW vw_fato_adocao_estante IS
'Adoção da funcionalidade de estante: estantes e produtos organizados por usuário.';
COMMENT ON COLUMN vw_fato_adocao_estante.id_usuario IS 'Usuário dono das estantes.';
COMMENT ON COLUMN vw_fato_adocao_estante.total_estantes IS 'Quantidade de estantes do usuário.';
COMMENT ON COLUMN vw_fato_adocao_estante.total_produtos_organizados IS 'Quantidade de produtos guardados nas estantes.';

COMMENT ON VIEW vw_qualidade_resolucao_fds IS
'Qualidade da resolução de compostos por FDS: quantos compostos viraram substância e quantos ficaram pendentes.';
COMMENT ON COLUMN vw_qualidade_resolucao_fds.id_fds IS 'FDS avaliada.';
COMMENT ON COLUMN vw_qualidade_resolucao_fds.nome_produto IS 'Produto da FDS.';
COMMENT ON COLUMN vw_qualidade_resolucao_fds.total_compostos IS 'Compostos declarados na seção 3.';
COMMENT ON COLUMN vw_qualidade_resolucao_fds.compostos_resolvidos IS 'Compostos com substância resolvida.';
COMMENT ON COLUMN vw_qualidade_resolucao_fds.compostos_pendentes IS 'Compostos sem substância (em sinonimo_pendente).';
COMMENT ON COLUMN vw_qualidade_resolucao_fds.pct_resolucao IS 'Percentual de compostos resolvidos.';

-- Catálogo ------------------------------------------------------------
COMMENT ON VIEW vw_catalogo_dados IS
'Catálogo de Dados pronto para exibição: uma linha por coluna, com a classificação da tabela.';
COMMENT ON COLUMN vw_catalogo_dados.nome_tabela IS 'Tabela ou view documentada.';
COMMENT ON COLUMN vw_catalogo_dados.tipo_objeto IS 'tabela ou view.';
COMMENT ON COLUMN vw_catalogo_dados.dominio IS 'Área de negócio do objeto.';
COMMENT ON COLUMN vw_catalogo_dados.nivel_acesso IS 'publico, interno ou restrito.';
COMMENT ON COLUMN vw_catalogo_dados.descricao_tabela IS 'Descrição do objeto.';
COMMENT ON COLUMN vw_catalogo_dados.regra_negocio_tabela IS 'Regra de negócio do objeto.';
COMMENT ON COLUMN vw_catalogo_dados.nome_coluna IS 'Coluna documentada.';
COMMENT ON COLUMN vw_catalogo_dados.tipo_dado IS 'Tipo físico da coluna.';
COMMENT ON COLUMN vw_catalogo_dados.obrigatorio IS 'Indica NOT NULL.';
COMMENT ON COLUMN vw_catalogo_dados.chave_primaria IS 'Indica se faz parte da PK.';
COMMENT ON COLUMN vw_catalogo_dados.referencia_tabela IS 'Tabela referenciada pela FK.';
COMMENT ON COLUMN vw_catalogo_dados.descricao_coluna IS 'Descrição da coluna.';
COMMENT ON COLUMN vw_catalogo_dados.regra_negocio_coluna IS 'Regra de negócio da coluna.';
COMMENT ON COLUMN vw_catalogo_dados.dado_pessoal_lgpd IS 'Indica dado pessoal (LGPD).';
COMMENT ON COLUMN vw_catalogo_dados.atualizado_em IS 'Última sincronização do objeto.';
