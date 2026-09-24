CREATE OR REPLACE VIEW dim_localizacao AS
SELECT DISTINCT estado, bairro FROM localizacao_usuario
UNION
SELECT DISTINCT estado, bairro FROM ponto_parceiro;