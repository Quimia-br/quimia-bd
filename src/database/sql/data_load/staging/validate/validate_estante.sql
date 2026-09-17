-- VALIDATE — stg_estante
-- Roda após o COPY bruto. Parâmetro :batch_id (UUID) do lote.

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

UPDATE stg_estante
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';