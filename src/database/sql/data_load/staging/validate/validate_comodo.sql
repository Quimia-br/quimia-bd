UPDATE stg_comodo
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario ausente'
WHERE id_batch = :batch_id
  AND (id_usuario_raw IS NULL OR btrim(id_usuario_raw) = '');

UPDATE stg_comodo
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_usuario_raw !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

UPDATE stg_comodo s
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario inexistente'
WHERE s.id_batch = :batch_id
  AND s.status = 'pendente'
  AND NOT EXISTS (
      SELECT 1 FROM usuario u WHERE u.id = s.id_usuario_raw::uuid
  );

UPDATE stg_comodo
SET status = 'rejeitado', motivo_rejeicao = 'nome excede 100 caracteres'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND length(nome_raw) > 100;

UPDATE stg_comodo
SET status = 'rejeitado', motivo_rejeicao = 'icone_comodo excede 250 caracteres'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND length(icone_comodo_raw) > 250;

WITH duplicados AS (
    SELECT ctid,
           ROW_NUMBER() OVER (
               PARTITION BY id_usuario_raw, lower(btrim(nome_raw))
               ORDER BY ctid
           ) AS rn
    FROM stg_comodo
    WHERE id_batch = :batch_id
      AND status = 'pendente'
)
UPDATE stg_comodo s
SET status = 'rejeitado', motivo_rejeicao = 'cômodo duplicado no lote para o mesmo usuário'
FROM duplicados d
WHERE s.ctid = d.ctid
  AND d.rn > 1;

UPDATE stg_comodo
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';