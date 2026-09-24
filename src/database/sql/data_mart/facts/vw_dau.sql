CREATE OR REPLACE VIEW vw_dau AS
SELECT ocorreu_em::date AS data, COUNT(DISTINCT id_usuario) AS usuarios_ativos
FROM sessao_acesso
GROUP BY ocorreu_em::date;