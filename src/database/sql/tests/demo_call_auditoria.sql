-- Demonstração da rubrica: CALL de procedure + trigger de auditoria.
-- Roda em transação com ROLLBACK: não deixa dados no banco.
-- psql -d <banco> -f src/database/sql/tests/demo_call_auditoria.sql
BEGIN;

-- usuário sem estante e um produto qualquer
SELECT u.id AS usuario, (SELECT MIN(id) FROM produto) AS produto
FROM usuario u
WHERE NOT EXISTS (SELECT 1 FROM estante e WHERE e.id_usuario = u.id)
ORDER BY u.id
LIMIT 1 \gset

-- 1) CALL: cria a estante padrão e guarda o produto (trg_validar_estante_produto valida o dono)
CALL guardar_produto_estante(:'usuario', :produto);

SELECT e.nome AS estante, ep.id_produto, ep.data_adicionado IS NOT NULL AS registrado
FROM estante e JOIN estante_produto ep ON ep.id_estante = e.id
WHERE e.id_usuario = :'usuario';

-- 2) Auditoria: UPDATE em usuario dispara trg_auditoria_usuario -> fn_auditoria
UPDATE usuario SET nome = nome || ' (demo)' WHERE id = :'usuario';

SELECT tabela_afetada, operacao,
       dado_anterior ->> 'nome' AS nome_old,
       dado_novo ->> 'nome'     AS nome_new,
       usuario_db
FROM log_auditoria
WHERE tabela_afetada = 'usuario' AND dado_novo ->> 'id' = :'usuario'
ORDER BY id DESC
LIMIT 1;

ROLLBACK;
