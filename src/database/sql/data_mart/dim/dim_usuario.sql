CREATE OR REPLACE VIEW dim_usuario AS
SELECT
    u.id AS id_usuario,
    u.nivel_acesso,
    lu.estado,
    lu.bairro
FROM usuario u
LEFT JOIN localizacao_usuario lu ON lu.id_usuario = u.id;