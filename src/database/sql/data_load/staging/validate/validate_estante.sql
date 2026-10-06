UPDATE stg_estante
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');

UPDATE stg_estante
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (id_usuario_raw IS NULL OR btrim(id_usuario_raw) = '');

UPDATE stg_estante
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_usuario_raw !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

UPDATE stg_estante se
SET status = 'rejeitado', motivo_rejeicao = 'usuario não encontrado'
WHERE se.id_batch = :batch_id
  AND se.status = 'pendente'
  AND NOT EXISTS (
      SELECT 1 FROM usuario u WHERE u.id = se.id_usuario_raw::uuid
  );

-- uma estante por usuário: rejeita repetição no lote e usuário que já tem estante
UPDATE stg_estante se
SET status = 'rejeitado', motivo_rejeicao = 'usuario já possui estante'
WHERE se.id_batch = :batch_id
  AND se.status = 'pendente'
  AND (
      EXISTS (
          SELECT 1 FROM stg_estante o
          WHERE o.id_batch = se.id_batch
            AND o.status = 'pendente'
            AND o.id < se.id
            AND o.id_usuario_raw::uuid = se.id_usuario_raw::uuid
      )
      OR EXISTS (SELECT 1 FROM estante e WHERE e.id_usuario = se.id_usuario_raw::uuid)
  );

UPDATE stg_estante
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';