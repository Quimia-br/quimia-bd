-- Aliases curados e conservadores de classe para a seção 10 da FDS.
-- NÃO mapear termos amplos (ex.: "materiais contendo nitrogênio" -> amonia_aminas).
INSERT INTO classe_quimica_sinonimo (id_classe_quimica, sinonimo_normalizado)
SELECT cq.id, v.alias
-- "comburente" é o termo das FDS em português de Portugal para oxidante.
FROM (VALUES ('agentes oxidantes', 'oxidantes'),
             ('agentes oxidantes fortes', 'oxidantes'),
             ('agentes comburentes', 'oxidantes'),
             ('agentes comburentes fortes', 'oxidantes')) AS v(alias, classe)
JOIN classe_quimica cq ON cq.nome = v.classe
ON CONFLICT (sinonimo_normalizado) DO NOTHING;
