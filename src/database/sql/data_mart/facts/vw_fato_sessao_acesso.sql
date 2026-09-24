CREATE OR REPLACE VIEW vw_fato_sessao_acesso AS
SELECT
    sa.ocorreu_em::date AS data,
    sa.id_usuario,
    COUNT(*) OVER (PARTITION BY sa.ocorreu_em::date) AS sessoes_no_dia
FROM sessao_acesso sa;