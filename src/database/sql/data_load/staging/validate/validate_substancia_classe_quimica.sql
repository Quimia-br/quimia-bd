-- VALIDATE — stg_substancia_classe_quimica
-- Roda após o COPY bruto. Parâmetro :batch_id (UUID) do lote.

UPDATE stg_substancia_classe_quimica
SET status = 'rejeitado', motivo_rejeicao = 'id_substancia vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (id_substancia_raw IS NULL OR btrim(id_substancia_raw) = '');

UPDATE stg_substancia_classe_quimica
SET status = 'rejeitado', motivo_rejeicao = 'id_classe_quimica vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (id_classe_quimica_raw IS NULL OR btrim(id_classe_quimica_raw) = '');

UPDATE stg_substancia_classe_quimica
SET status = 'rejeitado', motivo_rejeicao = 'id_substancia com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_substancia_raw !~ '^[0-9]+$';

UPDATE stg_substancia_classe_quimica
SET status = 'rejeitado', motivo_rejeicao = 'id_classe_quimica com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_classe_quimica_raw !~ '^[0-9]+$';

UPDATE stg_substancia_classe_quimica scq
SET status = 'rejeitado', motivo_rejeicao = 'substancia não encontrada'
WHERE scq.id_batch = :batch_id
  AND scq.status = 'pendente'
  AND NOT EXISTS (
      SELECT 1 FROM substancia s WHERE s.id = scq.id_substancia_raw::integer
  );

UPDATE stg_substancia_classe_quimica scq
SET status = 'rejeitado', motivo_rejeicao = 'classe_quimica não encontrada'
WHERE scq.id_batch = :batch_id
  AND scq.status = 'pendente'
  AND NOT EXISTS (
      SELECT 1 FROM classe_quimica c WHERE c.id = scq.id_classe_quimica_raw::integer
  );

WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY id_substancia_raw::integer, id_classe_quimica_raw::integer
               ORDER BY id
           ) AS rn
      FROM stg_substancia_classe_quimica
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_substancia_classe_quimica scq
SET status = 'rejeitado', motivo_rejeicao = 'par duplicado no lote'
FROM duplicatas d
WHERE scq.id = d.id
  AND d.rn > 1;

UPDATE stg_substancia_classe_quimica scq
SET status = 'rejeitado', motivo_rejeicao = 'par já cadastrado'
WHERE scq.id_batch = :batch_id
  AND scq.status = 'pendente'
  AND EXISTS (
      SELECT 1 FROM substancia_classe_quimica x
      WHERE x.id_substancia = scq.id_substancia_raw::integer
        AND x.id_classe_quimica = scq.id_classe_quimica_raw::integer
  );

UPDATE stg_substancia_classe_quimica
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';