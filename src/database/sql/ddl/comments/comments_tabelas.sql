-- =====================================================================
-- Catálogo de Dados — descrições de tabelas e colunas oficiais
-- Fonte única das descrições: fn_sincronizar_catalogo() copia estes
-- comentários (pg_description) para catalogo_tabela / catalogo_coluna.
-- =====================================================================

-- marca ---------------------------------------------------------------
COMMENT ON TABLE marca IS
'Catálogo de marcas dos produtos de limpeza.';
COMMENT ON COLUMN marca.id IS 'Identificador da marca.';
COMMENT ON COLUMN marca.nome IS 'Nome comercial da marca, único no sistema.';

-- empresa -------------------------------------------------------------
COMMENT ON TABLE empresa IS
'Empresa parceira (B2B2C), com login próprio para acessar dashboards de dados anonimizados.';
COMMENT ON COLUMN empresa.id IS 'Identificador da empresa.';
COMMENT ON COLUMN empresa.nome IS 'Razão social ou nome fantasia da empresa.';
COMMENT ON COLUMN empresa.email IS 'E-mail de login da empresa.';
COMMENT ON COLUMN empresa.cnpj IS 'CNPJ da empresa, único no sistema.';
COMMENT ON COLUMN empresa.ativo IS 'Indica se a parceria está ativa.';
COMMENT ON COLUMN empresa.senha IS 'Hash bcrypt da senha. A senha em texto nunca é armazenada.';
COMMENT ON COLUMN empresa.foto_url IS 'URL do logotipo da empresa.';

-- usuario -------------------------------------------------------------
COMMENT ON TABLE usuario IS
'Usuário final do app Quimia. Contém dados pessoais e credencial de acesso (LGPD: restrito).';
COMMENT ON COLUMN usuario.id IS 'Identificador UUID do usuário.';
COMMENT ON COLUMN usuario.nome IS 'Nome completo do usuário (dado pessoal).';
COMMENT ON COLUMN usuario.email IS 'E-mail de login, único no sistema.';
COMMENT ON COLUMN usuario.data_nasc IS 'Data de nascimento (dado pessoal).';
COMMENT ON COLUMN usuario.foto_url IS 'URL da foto de perfil (dado pessoal).';
COMMENT ON COLUMN usuario.senha IS 'Hash bcrypt da senha (60 caracteres). A senha em texto nunca é armazenada.';
COMMENT ON COLUMN usuario.nivel_acesso IS 'Perfil de acesso: usuario, empresa ou admin.';
COMMENT ON COLUMN usuario.ultima_sessao IS 'Último login, atualizado pela trigger trg_atualizar_ultima_sessao a partir de sessao_acesso.';

-- localizacao_usuario -------------------------------------------------
COMMENT ON TABLE localizacao_usuario IS
'Endereço do usuário (1:1 com usuario). Dado pessoal (LGPD: restrito); só estado e bairro vão para o Data Mart.';
COMMENT ON COLUMN localizacao_usuario.id IS 'Identificador do endereço.';
COMMENT ON COLUMN localizacao_usuario.id_usuario IS 'Usuário dono do endereço; único (um endereço por usuário).';
COMMENT ON COLUMN localizacao_usuario.cep IS 'CEP do endereço (dado pessoal).';
COMMENT ON COLUMN localizacao_usuario.estado IS 'UF com duas letras.';
COMMENT ON COLUMN localizacao_usuario.bairro IS 'Bairro do endereço (dado pessoal).';
COMMENT ON COLUMN localizacao_usuario.rua IS 'Logradouro (dado pessoal).';
COMMENT ON COLUMN localizacao_usuario.numero IS 'Número do imóvel (dado pessoal).';
COMMENT ON COLUMN localizacao_usuario.complemento IS 'Complemento do endereço (dado pessoal).';

-- classe_quimica ------------------------------------------------------
COMMENT ON TABLE classe_quimica IS
'Classes químicas usadas no motor de incompatibilidade (ex.: hipocloritos, acidos, amonia_aminas).';
COMMENT ON COLUMN classe_quimica.id IS 'Identificador da classe química.';
COMMENT ON COLUMN classe_quimica.nome IS 'Nome técnico da classe, único (ex.: hipocloritos, oxidantes).';
COMMENT ON COLUMN classe_quimica.descricao IS 'Explicação da classe e dos riscos típicos associados.';

-- substancia ----------------------------------------------------------
COMMENT ON TABLE substancia IS
'Catálogo de substâncias químicas presentes nos produtos.';
COMMENT ON COLUMN substancia.id IS 'Identificador da substância.';
COMMENT ON COLUMN substancia.nome_canonico IS 'Nome padrão da substância; usado normalizado (lower(unaccent(btrim()))) como último passo da resolução.';
COMMENT ON COLUMN substancia.cas_numero IS 'Número CAS, único; primeiro critério de resolução de compostos da FDS.';
COMMENT ON COLUMN substancia.descricao IS 'Descrição da substância em linguagem simples.';

-- substancia_sinonimo -------------------------------------------------
COMMENT ON TABLE substancia_sinonimo IS
'Nomes alternativos que apontam para uma substância; segundo passo da resolução de compostos da FDS.';
COMMENT ON COLUMN substancia_sinonimo.id IS 'Identificador do sinônimo.';
COMMENT ON COLUMN substancia_sinonimo.id_substancia IS 'Substância à qual o sinônimo se refere.';
COMMENT ON COLUMN substancia_sinonimo.sinonimo IS 'Nome alternativo como aparece na fonte.';
COMMENT ON COLUMN substancia_sinonimo.sinonimo_normalizado IS 'Sinônimo em lower(unaccent(btrim())), único globalmente para evitar ambiguidade.';

-- substancia_classe_quimica -------------------------------------------
COMMENT ON TABLE substancia_classe_quimica IS
'Associação N:N entre substância e classe química, curada via seed.';
COMMENT ON COLUMN substancia_classe_quimica.id IS 'Identificador da associação.';
COMMENT ON COLUMN substancia_classe_quimica.id_substancia IS 'Substância classificada.';
COMMENT ON COLUMN substancia_classe_quimica.id_classe_quimica IS 'Classe química atribuída; o par substância x classe é único.';

-- produto -------------------------------------------------------------
COMMENT ON TABLE produto IS
'Produto de limpeza doméstica cadastrado no app.';
COMMENT ON COLUMN produto.id IS 'Identificador do produto.';
COMMENT ON COLUMN produto.nome IS 'Nome comercial do produto.';
COMMENT ON COLUMN produto.id_marca IS 'Marca fabricante do produto.';
COMMENT ON COLUMN produto.descricao IS 'Descrição do produto e do seu uso.';
COMMENT ON COLUMN produto.tipo_produto IS 'Categoria: limpeza_geral, desinfetante, desincrustante, desengraxante, alvejante, aromatizante ou outro.';
COMMENT ON COLUMN produto.cod_barras IS 'Código de barras (EAN), único; usado na leitura pelo app.';
COMMENT ON COLUMN produto.foto_url IS 'URL da foto da embalagem.';

-- empresa_produto -----------------------------------------------------
COMMENT ON TABLE empresa_produto IS
'Associação N:N entre empresa parceira e produtos que ela comercializa ou acompanha.';
COMMENT ON COLUMN empresa_produto.id IS 'Identificador da associação.';
COMMENT ON COLUMN empresa_produto.id_empresa IS 'Empresa parceira.';
COMMENT ON COLUMN empresa_produto.id_produto IS 'Produto vinculado; o par empresa x produto é único.';
COMMENT ON COLUMN empresa_produto.ativo IS 'Indica se o vínculo está ativo.';
COMMENT ON COLUMN empresa_produto.data_cadastro IS 'Momento em que o vínculo foi criado.';

-- fds -----------------------------------------------------------------
COMMENT ON TABLE fds IS
'Ficha de Dados de Segurança (NBR 14725) de um produto. raw_json é a fonte de verdade; as tabelas fds_* são derivadas dele.';
COMMENT ON COLUMN fds.id IS 'Identificador da FDS.';
COMMENT ON COLUMN fds.id_produto IS 'Produto ao qual a ficha pertence.';
COMMENT ON COLUMN fds.versao IS 'Versão da ficha informada pelo fabricante.';
COMMENT ON COLUMN fds.data_atualizacao IS 'Data de revisão da ficha informada pelo fabricante.';
COMMENT ON COLUMN fds.ativo IS 'Indica se é a ficha vigente do produto.';
COMMENT ON COLUMN fds.fonte_url IS 'URL de origem do PDF da ficha.';
COMMENT ON COLUMN fds.raw_json IS 'JSON canônico gerado pelo parser de PDF; fonte de verdade. Chaves de seção são strings ("03", "10", "13"). Processado por trg_processar_fds_raw_json.';

-- fds_primeiro_socorro ------------------------------------------------
COMMENT ON TABLE fds_primeiro_socorro IS
'Medidas de primeiros socorros da seção 4 da FDS, uma linha por rota de exposição.';
COMMENT ON COLUMN fds_primeiro_socorro.id IS 'Identificador da medida.';
COMMENT ON COLUMN fds_primeiro_socorro.id_fds IS 'FDS de origem.';
COMMENT ON COLUMN fds_primeiro_socorro.rota_exposicao IS 'Via de exposição: inalacao, pele, olhos ou ingestao.';
COMMENT ON COLUMN fds_primeiro_socorro.descricao IS 'Procedimento de primeiros socorros para a rota.';
COMMENT ON COLUMN fds_primeiro_socorro.sintomas IS 'Sintomas esperados após a exposição.';
COMMENT ON COLUMN fds_primeiro_socorro.tratamento_especial IS 'Orientação de tratamento médico específico, se houver.';
COMMENT ON COLUMN fds_primeiro_socorro.atencao_medica_imediata IS 'Indica se a exposição exige atendimento médico imediato.';

-- fds_composto --------------------------------------------------------
COMMENT ON TABLE fds_composto IS
'Compostos declarados na seção 3 da FDS. Resolução da substância: CAS exato, depois sinônimo normalizado, depois nome canônico normalizado.';
COMMENT ON COLUMN fds_composto.id IS 'Identificador do composto na ficha.';
COMMENT ON COLUMN fds_composto.id_fds IS 'FDS de origem.';
COMMENT ON COLUMN fds_composto.id_substancia IS 'Substância resolvida; NULL quando não resolvida, caso em que existe pendência em sinonimo_pendente.';
COMMENT ON COLUMN fds_composto.concentracao_min IS 'Limite inferior da faixa de concentração; não pode exceder concentracao_max.';
COMMENT ON COLUMN fds_composto.concentracao_max IS 'Limite superior da faixa de concentração.';
COMMENT ON COLUMN fds_composto.unidade_concentracao IS 'Unidade da concentração (ex.: %).';

-- fds_incompatibilidade -----------------------------------------------
COMMENT ON TABLE fds_incompatibilidade IS
'Incompatibilidades declaradas na seção 10 da FDS (hoje o parser ainda não popula).';
COMMENT ON COLUMN fds_incompatibilidade.id IS 'Identificador da incompatibilidade.';
COMMENT ON COLUMN fds_incompatibilidade.id_fds IS 'FDS de origem.';
COMMENT ON COLUMN fds_incompatibilidade.id_substancia IS 'Substância reagente resolvida, se identificada.';
COMMENT ON COLUMN fds_incompatibilidade.id_classe_quimica IS 'Classe química reagente, se identificada.';
COMMENT ON COLUMN fds_incompatibilidade.substancia_reagente IS 'Texto bruto do reagente como aparece na ficha.';
COMMENT ON COLUMN fds_incompatibilidade.descricao_risco IS 'Risco descrito na ficha para a mistura.';
COMMENT ON COLUMN fds_incompatibilidade.severidade IS 'Gravidade: baixa, media, alta ou critica.';

-- fds_descarte --------------------------------------------------------
COMMENT ON TABLE fds_descarte IS
'Instruções de descarte da seção 13 da FDS.';
COMMENT ON COLUMN fds_descarte.id IS 'Identificador da instrução.';
COMMENT ON COLUMN fds_descarte.id_fds IS 'FDS de origem.';
COMMENT ON COLUMN fds_descarte.instrucao_descarte IS 'Orientação de descarte do produto ou da embalagem.';
COMMENT ON COLUMN fds_descarte.tipo_residuo IS 'Tipo de resíduo: quimico, biologico, comum, reciclavel ou outro.';

-- incompatibilidade_regra ---------------------------------------------
COMMENT ON TABLE incompatibilidade_regra IS
'Catálogo curado de reações perigosas. Cada lado da regra é uma substância OU uma classe química, nunca os dois.';
COMMENT ON COLUMN incompatibilidade_regra.id IS 'Identificador da regra.';
COMMENT ON COLUMN incompatibilidade_regra.id_substancia_a IS 'Substância do lado A; exclusiva com id_classe_a (XOR).';
COMMENT ON COLUMN incompatibilidade_regra.id_classe_a IS 'Classe química do lado A; exclusiva com id_substancia_a (XOR).';
COMMENT ON COLUMN incompatibilidade_regra.id_substancia_b IS 'Substância do lado B; exclusiva com id_classe_b (XOR).';
COMMENT ON COLUMN incompatibilidade_regra.id_classe_b IS 'Classe química do lado B; exclusiva com id_substancia_b (XOR).';
COMMENT ON COLUMN incompatibilidade_regra.severidade IS 'Gravidade da reação: baixa, media, alta ou critica.';
COMMENT ON COLUMN incompatibilidade_regra.descricao_risco IS 'Explicação do risco da mistura exibida ao usuário.';
COMMENT ON COLUMN incompatibilidade_regra.fonte IS 'Referência técnica que embasa a regra.';
COMMENT ON COLUMN incompatibilidade_regra.ativo IS 'Somente regras ativas são consideradas por fn_match_produtos.';

-- sinonimo_pendente ---------------------------------------------------
COMMENT ON TABLE sinonimo_pendente IS
'Fila de curadoria humana para compostos de FDS que não foram resolvidos para uma substância.';
COMMENT ON COLUMN sinonimo_pendente.id IS 'Identificador da pendência.';
COMMENT ON COLUMN sinonimo_pendente.termo_bruto IS 'Nome do composto como veio da ficha.';
COMMENT ON COLUMN sinonimo_pendente.cas_bruto IS 'CAS como veio da ficha, se informado.';
COMMENT ON COLUMN sinonimo_pendente.id_fds IS 'FDS onde o termo apareceu.';
COMMENT ON COLUMN sinonimo_pendente.status IS 'Situação da curadoria: pendente, resolvido ou descartado.';
COMMENT ON COLUMN sinonimo_pendente.id_substancia_resolvida IS 'Substância escolhida pelo curador ao resolver a pendência.';
COMMENT ON COLUMN sinonimo_pendente.criado_em IS 'Momento em que a pendência foi aberta.';
COMMENT ON COLUMN sinonimo_pendente.resolvido_em IS 'Momento em que a pendência foi resolvida ou descartada.';

-- estante -------------------------------------------------------------
COMMENT ON TABLE estante IS
'Agrupamento pessoal de produtos do usuário (ex.: "Área de serviço").';
COMMENT ON COLUMN estante.id IS 'Identificador da estante.';
COMMENT ON COLUMN estante.id_usuario IS 'Usuário dono da estante.';
COMMENT ON COLUMN estante.nome IS 'Nome dado pelo usuário à estante.';
COMMENT ON COLUMN estante.ambiente IS 'Cômodo ou ambiente da casa onde os produtos ficam.';
COMMENT ON COLUMN estante.criado_em IS 'Momento de criação da estante.';

-- estante_produto -----------------------------------------------------
COMMENT ON TABLE estante_produto IS
'Produtos guardados em cada estante do usuário.';
COMMENT ON COLUMN estante_produto.id IS 'Identificador do item na estante.';
COMMENT ON COLUMN estante_produto.id_produto IS 'Produto guardado.';
COMMENT ON COLUMN estante_produto.id_usuario IS 'Usuário dono; deve ser o mesmo dono da estante.';
COMMENT ON COLUMN estante_produto.id_estante IS 'Estante onde o produto está; o par estante x produto é único.';

-- historico_recomendacao ----------------------------------------------
COMMENT ON TABLE historico_recomendacao IS
'Log de cada consulta de produto feita pelo usuário, com o resultado da recomendação.';
COMMENT ON COLUMN historico_recomendacao.id IS 'Identificador da consulta.';
COMMENT ON COLUMN historico_recomendacao.id_produto IS 'Produto consultado.';
COMMENT ON COLUMN historico_recomendacao.id_usuario IS 'Usuário que fez a consulta.';
COMMENT ON COLUMN historico_recomendacao.resultado IS 'Resultado: compativel, incompativel, atencao ou nao_avaliado.';
COMMENT ON COLUMN historico_recomendacao.dosagem_sugerida IS 'Dosagem convertida em medida caseira mostrada ao usuário.';
COMMENT ON COLUMN historico_recomendacao.data_consulta IS 'Momento da consulta.';

-- historico_match -----------------------------------------------------
COMMENT ON TABLE historico_match IS
'Registro de cada comparação produto x produto feita pelo usuário para detectar mistura perigosa. Par normalizado: id_produto_a < id_produto_b.';
COMMENT ON COLUMN historico_match.id IS 'Identificador da comparação.';
COMMENT ON COLUMN historico_match.id_usuario IS 'Usuário que fez a comparação.';
COMMENT ON COLUMN historico_match.id_produto_a IS 'Produto de menor id do par.';
COMMENT ON COLUMN historico_match.id_produto_b IS 'Produto de maior id do par.';
COMMENT ON COLUMN historico_match.resultado IS
'Veredito de fn_match_produtos: compativel, incompativel ou nao_avaliado (sem composto resolvido não significa seguro).';
COMMENT ON COLUMN historico_match.id_regra IS 'Regra de incompatibilidade_regra que disparou o alerta, se houver.';
COMMENT ON COLUMN historico_match.severidade IS 'Gravidade da regra disparada: baixa, media, alta ou critica.';
COMMENT ON COLUMN historico_match.descricao_risco IS 'Risco mostrado ao usuário no momento da comparação.';
COMMENT ON COLUMN historico_match.data_consulta IS 'Momento da comparação.';

-- ponto_parceiro ------------------------------------------------------
COMMENT ON TABLE ponto_parceiro IS
'Pontos físicos de compra ou de descarte de embalagens mantidos pelas empresas parceiras.';
COMMENT ON COLUMN ponto_parceiro.id IS 'Identificador do ponto.';
COMMENT ON COLUMN ponto_parceiro.id_empresa IS 'Empresa responsável pelo ponto.';
COMMENT ON COLUMN ponto_parceiro.nome IS 'Nome do estabelecimento.';
COMMENT ON COLUMN ponto_parceiro.cep IS 'CEP do ponto.';
COMMENT ON COLUMN ponto_parceiro.estado IS 'UF com duas letras.';
COMMENT ON COLUMN ponto_parceiro.bairro IS 'Bairro do ponto.';
COMMENT ON COLUMN ponto_parceiro.rua IS 'Logradouro do ponto.';
COMMENT ON COLUMN ponto_parceiro.numero IS 'Número do imóvel.';
COMMENT ON COLUMN ponto_parceiro.complemento IS 'Complemento do endereço.';
COMMENT ON COLUMN ponto_parceiro.tipo IS 'Finalidade do ponto: compra ou descarte.';
COMMENT ON COLUMN ponto_parceiro.ativo IS 'Indica se o ponto está em funcionamento.';

-- sessao_acesso -------------------------------------------------------
COMMENT ON TABLE sessao_acesso IS
'Log de login inserido pelo backend a cada acesso; base do DAU.';
COMMENT ON COLUMN sessao_acesso.id IS 'Identificador da sessão.';
COMMENT ON COLUMN sessao_acesso.id_usuario IS 'Usuário que fez login.';
COMMENT ON COLUMN sessao_acesso.ocorreu_em IS 'Momento do login; dispara trg_atualizar_ultima_sessao.';

-- log_auditoria -------------------------------------------------------
COMMENT ON TABLE log_auditoria IS
'Auditoria genérica preenchida pela trigger fn_auditoria em usuario e fds (LGPD: restrito, pode conter dados pessoais).';
COMMENT ON COLUMN log_auditoria.id IS 'Identificador do evento de auditoria.';
COMMENT ON COLUMN log_auditoria.tabela_afetada IS 'Tabela alterada (TG_TABLE_NAME).';
COMMENT ON COLUMN log_auditoria.operacao IS 'Operação executada (TG_OP): INSERT, UPDATE ou DELETE.';
COMMENT ON COLUMN log_auditoria.dado_anterior IS 'Linha antes da alteração (OLD) em JSON; NULL em INSERT.';
COMMENT ON COLUMN log_auditoria.dado_novo IS 'Linha depois da alteração (NEW) em JSON; NULL em DELETE.';
COMMENT ON COLUMN log_auditoria.usuario_db IS 'Usuário do banco que executou a operação (CURRENT_USER).';
COMMENT ON COLUMN log_auditoria.alterado_em IS 'Momento da operação.';

-- catalogo_tabela -----------------------------------------------------
COMMENT ON TABLE catalogo_tabela IS
'Catálogo de Dados: uma linha por tabela ou view oficial. Estrutura e descrição vêm de fn_sincronizar_catalogo; classificação vem do seed.';
COMMENT ON COLUMN catalogo_tabela.id IS 'Identificador da entrada do catálogo.';
COMMENT ON COLUMN catalogo_tabela.nome_tabela IS 'Nome da tabela ou view no schema public, único.';
COMMENT ON COLUMN catalogo_tabela.tipo_objeto IS 'Tipo do objeto: tabela ou view.';
COMMENT ON COLUMN catalogo_tabela.dominio IS 'Área de negócio: cadastro, fds, curadoria, interacao, auditoria, dimensional, fato ou catalogo.';
COMMENT ON COLUMN catalogo_tabela.descricao IS 'Descrição copiada do COMMENT ON do objeto.';
COMMENT ON COLUMN catalogo_tabela.regra_negocio IS 'Regras de negócio que valem para o objeto como um todo.';
COMMENT ON COLUMN catalogo_tabela.nivel_acesso IS 'Nível de acesso: publico, interno ou restrito (restrito = contém dado pessoal ou sensível).';
COMMENT ON COLUMN catalogo_tabela.responsavel IS 'Equipe ou pessoa responsável pelo objeto.';
COMMENT ON COLUMN catalogo_tabela.atualizado_em IS 'Última sincronização da entrada.';

-- catalogo_coluna -----------------------------------------------------
COMMENT ON TABLE catalogo_coluna IS
'Catálogo de Dados: uma linha por coluna de cada objeto em catalogo_tabela.';
COMMENT ON COLUMN catalogo_coluna.id IS 'Identificador da entrada de coluna.';
COMMENT ON COLUMN catalogo_coluna.id_catalogo_tabela IS 'Objeto ao qual a coluna pertence; o par objeto x coluna é único.';
COMMENT ON COLUMN catalogo_coluna.nome_coluna IS 'Nome da coluna.';
COMMENT ON COLUMN catalogo_coluna.tipo_dado IS 'Tipo físico lido do pg_catalog (format_type).';
COMMENT ON COLUMN catalogo_coluna.obrigatorio IS 'Indica se a coluna é NOT NULL.';
COMMENT ON COLUMN catalogo_coluna.chave_primaria IS 'Indica se a coluna faz parte da chave primária.';
COMMENT ON COLUMN catalogo_coluna.referencia_tabela IS 'Tabela apontada pela chave estrangeira, se houver.';
COMMENT ON COLUMN catalogo_coluna.descricao_negocio IS 'Descrição copiada do COMMENT ON da coluna.';
COMMENT ON COLUMN catalogo_coluna.regra_negocio IS 'Regra de negócio aplicada à coluna (preenchida pelo seed de classificação).';
COMMENT ON COLUMN catalogo_coluna.dado_pessoal_lgpd IS 'Indica se a coluna guarda dado pessoal protegido pela LGPD.';

-- Tabelas do backend Java (criadas por Flyway, fora deste repositório) --
-- Só comentadas se existirem: num banco recriado apenas pelo setup_data.py
-- elas não estão presentes.
DO $$
BEGIN
    IF to_regclass('public.refresh_token') IS NOT NULL THEN
        EXECUTE $c$COMMENT ON TABLE refresh_token IS 'Refresh tokens de sessão do app, com rotação por família. Mantida pelo backend Java via Flyway (LGPD: restrito, credencial).'$c$;
        EXECUTE $c$COMMENT ON COLUMN refresh_token.id IS 'Identificador UUID do token.'$c$;
        EXECUTE $c$COMMENT ON COLUMN refresh_token.id_usuario IS 'Usuário dono do token.'$c$;
        EXECUTE $c$COMMENT ON COLUMN refresh_token.token_hash IS 'Hash do refresh token, único. O token em texto nunca é armazenado.'$c$;
        EXECUTE $c$COMMENT ON COLUMN refresh_token.familia_id IS 'Família de rotação: tokens emitidos a partir do mesmo login compartilham este id.'$c$;
        EXECUTE $c$COMMENT ON COLUMN refresh_token.expira_em IS 'Momento em que o token deixa de ser válido.'$c$;
        EXECUTE $c$COMMENT ON COLUMN refresh_token.revogado_em IS 'Momento da revogação; NULL enquanto válido.'$c$;
        EXECUTE $c$COMMENT ON COLUMN refresh_token.substituido_por IS 'Token que substituiu este na rotação.'$c$;
        EXECUTE $c$COMMENT ON COLUMN refresh_token.ultimo_uso_em IS 'Último uso do token para renovar a sessão.'$c$;
        EXECUTE $c$COMMENT ON COLUMN refresh_token.criado_em IS 'Momento de emissão do token.'$c$;
    END IF;

    IF to_regclass('public.auditoria_autenticacao') IS NOT NULL THEN
        EXECUTE $c$COMMENT ON TABLE auditoria_autenticacao IS 'Log de eventos de autenticação (login, logout, falhas) gravado pelo backend Java (LGPD: restrito).'$c$;
        EXECUTE $c$COMMENT ON COLUMN auditoria_autenticacao.id IS 'Identificador do evento.'$c$;
        EXECUTE $c$COMMENT ON COLUMN auditoria_autenticacao.id_usuario IS 'Usuário envolvido; NULL quando não identificado (ex.: login com e-mail inexistente).'$c$;
        EXECUTE $c$COMMENT ON COLUMN auditoria_autenticacao.evento IS 'Tipo do evento de autenticação.'$c$;
        EXECUTE $c$COMMENT ON COLUMN auditoria_autenticacao.criado_em IS 'Momento do evento.'$c$;
    END IF;
END;
$$;
