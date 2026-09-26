CREATE OR REPLACE VIEW vw_catalogo_dados AS
SELECT
    ct.nome_tabela,
    ct.tipo_objeto,
    ct.dominio,
    ct.nivel_acesso,
    ct.descricao          AS descricao_tabela,
    ct.regra_negocio      AS regra_negocio_tabela,
    cc.nome_coluna,
    cc.tipo_dado,
    cc.obrigatorio,
    cc.chave_primaria,
    cc.referencia_tabela,
    cc.descricao_negocio  AS descricao_coluna,
    cc.regra_negocio      AS regra_negocio_coluna,
    cc.dado_pessoal_lgpd,
    ct.atualizado_em
FROM catalogo_tabela ct
JOIN catalogo_coluna cc ON cc.id_catalogo_tabela = ct.id;
