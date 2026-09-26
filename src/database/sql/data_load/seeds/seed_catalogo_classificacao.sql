-- =====================================================================
-- Catálogo de Dados — classificação (domínio, nível de acesso, LGPD,
-- regras de negócio). Executar DEPOIS de fn_sincronizar_catalogo().
-- A sincronização nunca sobrescreve estes campos.
-- =====================================================================

-- Domínio e nível de acesso -------------------------------------------
UPDATE catalogo_tabela SET dominio = 'cadastro', nivel_acesso = 'publico'
 WHERE nome_tabela IN ('marca', 'produto', 'substancia', 'classe_quimica',
                       'substancia_classe_quimica', 'substancia_sinonimo');

UPDATE catalogo_tabela SET dominio = 'cadastro', nivel_acesso = 'interno'
 WHERE nome_tabela IN ('empresa', 'empresa_produto', 'ponto_parceiro');

UPDATE catalogo_tabela SET dominio = 'cadastro', nivel_acesso = 'restrito'
 WHERE nome_tabela IN ('usuario', 'localizacao_usuario');

UPDATE catalogo_tabela SET dominio = 'fds', nivel_acesso = 'publico'
 WHERE nome_tabela IN ('fds', 'fds_composto', 'fds_incompatibilidade',
                       'fds_descarte', 'fds_primeiro_socorro');

UPDATE catalogo_tabela SET dominio = 'curadoria', nivel_acesso = 'interno'
 WHERE nome_tabela IN ('sinonimo_pendente', 'incompatibilidade_regra');

UPDATE catalogo_tabela SET dominio = 'interacao', nivel_acesso = 'interno'
 WHERE nome_tabela IN ('estante', 'estante_produto',
                       'historico_recomendacao', 'historico_match');

UPDATE catalogo_tabela SET dominio = 'auditoria', nivel_acesso = 'restrito'
 WHERE nome_tabela IN ('sessao_acesso', 'log_auditoria');

-- Tabelas do backend Java (Flyway); no-op quando não existem
UPDATE catalogo_tabela SET dominio = 'auditoria', nivel_acesso = 'restrito',
       responsavel = 'Equipe Quimia Backend'
 WHERE nome_tabela IN ('refresh_token', 'auditoria_autenticacao');

UPDATE catalogo_tabela SET dominio = 'dimensional', nivel_acesso = 'interno'
 WHERE nome_tabela LIKE 'dim\_%';

UPDATE catalogo_tabela SET dominio = 'fato', nivel_acesso = 'interno'
 WHERE nome_tabela LIKE 'vw\_%'
   AND nome_tabela <> 'vw_catalogo_dados';

UPDATE catalogo_tabela SET dominio = 'catalogo', nivel_acesso = 'interno'
 WHERE nome_tabela IN ('catalogo_tabela', 'catalogo_coluna', 'vw_catalogo_dados');

UPDATE catalogo_tabela SET responsavel = 'Equipe Quimia BD'
 WHERE responsavel IS NULL;

-- Regras de negócio por tabela ----------------------------------------
UPDATE catalogo_tabela AS ct SET regra_negocio = v.regra
  FROM (VALUES
    ('usuario',                 'Dado pessoal: acesso só pelo próprio usuário e admin. Alterações auditadas por trg_auditoria_usuario.'),
    ('localizacao_usuario',     'Um endereço por usuário. Só estado e bairro podem sair para o Data Mart.'),
    ('empresa',                 'Login próprio da empresa parceira; enxerga apenas dados anonimizados.'),
    ('fds',                     'raw_json é a fonte de verdade; tabelas fds_* são regeneradas por trg_processar_fds_raw_json. Alterações auditadas por trg_auditoria_fds.'),
    ('fds_composto',            'Resolução de substância: CAS exato, sinônimo normalizado, nome canônico normalizado; senão vira pendência em sinonimo_pendente.'),
    ('incompatibilidade_regra', 'Cada lado é substância OU classe química (XOR). Só regras ativas entram no match.'),
    ('sinonimo_pendente',       'Toda pendência resolvida deve apontar para uma substância e ter resolvido_em preenchido.'),
    ('historico_match',         'Par normalizado (id_produto_a < id_produto_b). nao_avaliado não significa seguro.'),
    ('sessao_acesso',           'Inserida pelo backend a cada login; alimenta usuario.ultima_sessao e o DAU.'),
    ('log_auditoria',           'Somente inserção por trigger; pode conter dados pessoais em JSON.'),
    ('dim_usuario',             'Não expõe nome nem e-mail (LGPD).')
  ) AS v(tabela, regra)
 WHERE ct.nome_tabela = v.tabela;

-- Colunas com dado pessoal (LGPD) -------------------------------------
UPDATE catalogo_coluna AS cc SET dado_pessoal_lgpd = TRUE
  FROM catalogo_tabela ct
 WHERE ct.id = cc.id_catalogo_tabela
   AND (ct.nome_tabela, cc.nome_coluna) IN (
        ('usuario', 'nome'), ('usuario', 'email'), ('usuario', 'data_nasc'),
        ('usuario', 'foto_url'), ('usuario', 'senha'),
        ('localizacao_usuario', 'cep'), ('localizacao_usuario', 'bairro'),
        ('localizacao_usuario', 'rua'), ('localizacao_usuario', 'numero'),
        ('localizacao_usuario', 'complemento'),
        ('empresa', 'email'), ('empresa', 'senha'),
        ('log_auditoria', 'dado_anterior'), ('log_auditoria', 'dado_novo'),
        ('refresh_token', 'token_hash')
   );

-- Regras de negócio por coluna ----------------------------------------
UPDATE catalogo_coluna AS cc SET regra_negocio = v.regra
  FROM catalogo_tabela ct,
       (VALUES
        ('usuario', 'senha',                         'Armazenar apenas hash bcrypt.'),
        ('usuario', 'email',                         'Único no sistema.'),
        ('usuario', 'nivel_acesso',                  'Valores permitidos: usuario, empresa, admin (CHECK).'),
        ('usuario', 'ultima_sessao',                 'Mantida por trigger; não atualizar manualmente.'),
        ('empresa', 'senha',                         'Armazenar apenas hash bcrypt.'),
        ('empresa', 'cnpj',                          'Único no sistema.'),
        ('localizacao_usuario', 'id_usuario',        'Único: no máximo um endereço por usuário.'),
        ('marca', 'nome',                            'Único no sistema.'),
        ('classe_quimica', 'nome',                   'Único no sistema.'),
        ('substancia', 'cas_numero',                 'Único; primeiro critério de resolução.'),
        ('substancia_sinonimo', 'sinonimo_normalizado', 'lower(unaccent(btrim(sinonimo))); único globalmente.'),
        ('produto', 'tipo_produto',                  'Valores permitidos: limpeza_geral, desinfetante, desincrustante, desengraxante, alvejante, aromatizante, outro (CHECK).'),
        ('produto', 'cod_barras',                    'Único no sistema.'),
        ('fds', 'raw_json',                          'Fonte de verdade; chaves de seção são strings ("03", "10", "13").'),
        ('fds_composto', 'id_substancia',            'NULL quando não resolvido; gera pendência em sinonimo_pendente.'),
        ('fds_composto', 'concentracao_min',         'Menor ou igual a concentracao_max (CHECK).'),
        ('fds_primeiro_socorro', 'rota_exposicao',   'Valores permitidos: inalacao, pele, olhos, ingestao (CHECK).'),
        ('fds_descarte', 'tipo_residuo',             'Valores permitidos: quimico, biologico, comum, reciclavel, outro (CHECK).'),
        ('fds_incompatibilidade', 'severidade',      'Valores permitidos: baixa, media, alta, critica (CHECK).'),
        ('incompatibilidade_regra', 'id_substancia_a', 'Substância ou classe, nunca os dois (XOR com id_classe_a).'),
        ('incompatibilidade_regra', 'id_classe_a',     'Substância ou classe, nunca os dois (XOR com id_substancia_a).'),
        ('incompatibilidade_regra', 'id_substancia_b', 'Substância ou classe, nunca os dois (XOR com id_classe_b).'),
        ('incompatibilidade_regra', 'id_classe_b',     'Substância ou classe, nunca os dois (XOR com id_substancia_b).'),
        ('incompatibilidade_regra', 'severidade',      'Valores permitidos: baixa, media, alta, critica (CHECK).'),
        ('sinonimo_pendente', 'status',              'Valores permitidos: pendente, resolvido, descartado (CHECK).'),
        ('estante_produto', 'id_usuario',            'Deve ser o mesmo dono da estante (garantido pela trg_validar_estante_produto).'),
        ('historico_match', 'id_produto_a',          'Sempre menor que id_produto_b (CHECK).'),
        ('historico_match', 'resultado',             'Valores permitidos: compativel, incompativel, nao_avaliado (CHECK).'),
        ('historico_recomendacao', 'resultado',      'Valores permitidos: compativel, incompativel, atencao, nao_avaliado (CHECK).'),
        ('ponto_parceiro', 'tipo',                   'Valores permitidos: compra, descarte (CHECK).'),
        ('log_auditoria', 'operacao',                'Preenchida com TG_OP: INSERT, UPDATE, DELETE (CHECK).'),
        ('log_auditoria', 'usuario_db',              'Preenchida com CURRENT_USER.'),
        ('refresh_token', 'token_hash',              'Armazenar apenas hash; único.')
       ) AS v(tabela, coluna, regra)
 WHERE ct.id = cc.id_catalogo_tabela
   AND ct.nome_tabela = v.tabela
   AND cc.nome_coluna = v.coluna;
