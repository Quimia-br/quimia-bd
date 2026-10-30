BEGIN;

SELECT u.id AS usuario, (SELECT MIN(id) FROM produto) AS produto
FROM usuario u
WHERE NOT EXISTS (SELECT 1 FROM estante e WHERE e.id_usuario = u.id)
ORDER BY u.id
LIMIT 1 \gset

CALL guardar_produto_estante(:'usuario', :produto);

SELECT e.nome AS estante, ep.id_produto, ep.data_adicionado IS NOT NULL AS registrado
FROM estante e JOIN estante_produto ep ON ep.id_estante = e.id
WHERE e.id_usuario = :'usuario';

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
