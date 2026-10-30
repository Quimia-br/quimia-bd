-- Testes de fn_match_produtos e da resolução de compostos. Tudo em transação com ROLLBACK.
-- Uso: psql -v ON_ERROR_STOP=1 -f test_fn_match.sql  (ler a coluna "ok" de cada cenário)
BEGIN;

UPDATE fds SET ativo = FALSE;

SELECT (SELECT id FROM produto ORDER BY id LIMIT 1 OFFSET 0) AS pa,
       (SELECT id FROM produto ORDER BY id LIMIT 1 OFFSET 1) AS pb \gset

INSERT INTO fds (id_produto, versao, raw_json) VALUES (:pa, 'teste', '{}'::jsonb), (:pb, 'teste', '{}'::jsonb);

-- Monta os compostos de A e B (por nome canônico), opcionalmente com pendência em A, e devolve o match.
CREATE FUNCTION pg_temp.cenario(a TEXT[], b TEXT[], pendente BOOLEAN DEFAULT FALSE)
RETURNS TABLE (resultado VARCHAR, id_regra INTEGER, severidade VARCHAR) AS $$
BEGIN
    DELETE FROM sinonimo_pendente WHERE termo_bruto = 'teste_pendente';
    DELETE FROM fds_composto WHERE id_fds IN (SELECT id FROM fds WHERE versao = 'teste');
    INSERT INTO fds_composto (id_fds, id_substancia)
    SELECT f.id, s.id FROM fds f JOIN substancia s ON s.nome_canonico = ANY(a)
    WHERE f.versao = 'teste' AND f.id_produto = (SELECT MIN(id_produto) FROM fds WHERE versao = 'teste');
    INSERT INTO fds_composto (id_fds, id_substancia)
    SELECT f.id, s.id FROM fds f JOIN substancia s ON s.nome_canonico = ANY(b)
    WHERE f.versao = 'teste' AND f.id_produto = (SELECT MAX(id_produto) FROM fds WHERE versao = 'teste');
    IF pendente THEN
        INSERT INTO sinonimo_pendente (termo_bruto, id_fds)
        SELECT 'teste_pendente', MIN(id) FROM fds WHERE versao = 'teste';
    END IF;
    RETURN QUERY SELECT m.resultado, m.id_regra, m.severidade
                 FROM fn_match_produtos((SELECT MIN(id_produto) FROM fds WHERE versao = 'teste'),
                                        (SELECT MAX(id_produto) FROM fds WHERE versao = 'teste')) m;
END $$ LANGUAGE plpgsql;

SELECT 'T1 hipoclorito x HCl' AS cenario, resultado, severidade,
       resultado = 'incompativel' AND severidade = 'critica' AS ok
FROM pg_temp.cenario(ARRAY['Hipoclorito de sódio'], ARRAY['Ácido clorídrico']) LIMIT 1;

SELECT 'T2 hipoclorito x amônia', resultado, severidade,
       resultado = 'incompativel' AND severidade = 'critica'
FROM pg_temp.cenario(ARRAY['Hipoclorito de sódio'], ARRAY['Amônia']) LIMIT 1;

SELECT 'T3 hipoclorito x etanol', resultado, severidade,
       resultado = 'incompativel' AND severidade = 'alta'
FROM pg_temp.cenario(ARRAY['Hipoclorito de sódio'], ARRAY['Etanol']) LIMIT 1;

SELECT 'T4 dicloroisocianurato x propano', resultado, severidade, resultado = 'compativel'
FROM pg_temp.cenario(ARRAY['Dicloroisocianurato de sódio'], ARRAY['Propano']);

SELECT 'T5 mistura x sem regra', resultado, severidade, resultado = 'nao_avaliado'
FROM pg_temp.cenario(ARRAY['Tensoativo (mistura)', 'Propano'], ARRAY['Dicloroisocianurato de sódio']);

SELECT 'T6 alerta prevalece sobre mistura', resultado, severidade, resultado = 'incompativel'
FROM pg_temp.cenario(ARRAY['Hipoclorito de sódio', 'Tensoativo (mistura)'], ARRAY['Ácido clorídrico']) LIMIT 1;

SELECT 'T7 pendência aberta', resultado, severidade, resultado = 'nao_avaliado'
FROM pg_temp.cenario(ARRAY['Dicloroisocianurato de sódio'], ARRAY['Propano'], TRUE);

-- T8: regra 4 (inativa) não dispara: aniônico x catiônico
SELECT 'T8 regra inativa não dispara', resultado, id_regra,
       NOT EXISTS (SELECT 1 FROM incompatibilidade_regra r WHERE r.id = x.id_regra AND NOT r.ativo) AS ok
FROM pg_temp.cenario(ARRAY['Lauril sulfato de sódio'], ARRAY['Tensoativo catiônico (mistura)']) x;

-- T9: resolução por sinônimo; CAS de mistura genérica não resolve para outra mistura
UPDATE fds SET raw_json = '{"status":"ok","secoes":{"03":{"compostos":[
  {"nome":"Soda cáustica"},{"nome":"Água oxigenada"},
  {"nome":"TENSOATIVO ANIÔNICO","cas_numero":"68411-30-3"}]}}}'::jsonb
WHERE versao = 'teste' AND id_produto = :pa;

SELECT 'T9 resolvidos=2 pendentes=1' AS cenario,
       COUNT(fc.id_substancia) AS resolvidos,
       COUNT(*) FILTER (WHERE fc.id_substancia IS NULL) AS pendentes,
       COUNT(fc.id_substancia) = 2 AND COUNT(*) FILTER (WHERE fc.id_substancia IS NULL) = 1 AS ok
FROM fds_composto fc JOIN fds f ON f.id = fc.id_fds
WHERE f.versao = 'teste' AND f.id_produto = :pa;

-- T10: regra no nível da substância (peróxido x ácido acético), criada só nesta transação
INSERT INTO incompatibilidade_regra (id_substancia_a, id_substancia_b, severidade, descricao_risco, ativo)
SELECT a.id, b.id, 'alta', 'teste', TRUE
FROM substancia a, substancia b
WHERE a.nome_canonico = 'Peróxido de hidrogênio' AND b.nome_canonico = 'Ácido acético';

SELECT 'T10 regra de substância', resultado, severidade,
       resultado = 'incompativel' AND severidade = 'alta'
FROM pg_temp.cenario(ARRAY['Peróxido de hidrogênio'], ARRAY['Ácido acético']) LIMIT 1;

-- T11: "Agentes oxidantes" da seção 10 resolve para a classe oxidantes via alias
UPDATE fds SET raw_json = '{"status":"ok","secoes":{"10":{"incompatibilidades":[
  {"substancia_reagente":"Agentes oxidantes","descricao_risco":"teste"}]}}}'::jsonb
WHERE versao = 'teste' AND id_produto = :pa;

SELECT 'T11 alias de classe' AS cenario, cq.nome AS classe, cq.nome = 'oxidantes' AS ok
FROM fds_incompatibilidade fi JOIN fds f ON f.id = fi.id_fds
LEFT JOIN classe_quimica cq ON cq.id = fi.id_classe_quimica
WHERE f.versao = 'teste' AND f.id_produto = :pa;

ROLLBACK;
