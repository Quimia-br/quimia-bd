-- VALIDATE — stg_substancia_sinonimo
-- Roda após o COPY bruto. Parâmetro :batch_id (UUID) do lote.
-- Requer extensão unaccent (CREATE EXTENSION IF NOT EXISTS unaccent;)
-- pra normalização de acento bater com o que o migrate vai gravar.

UPDATE stg_substancia_sinonimo
SET status = 'rejeitado', motivo_rejeicao = 'id_substancia vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (id_substancia_raw IS NULL OR btrim(id_substancia_raw) = '');

UPDATE stg_substancia_sinonimo
SET status = 'rejeitado', motivo_rejeicao = 'sinonimo vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (sinonimo_raw IS NULL OR btrim(sinonimo_raw) = '');

UPDATE stg_substancia_sinonimo
SET status = 'rejeitado', motivo_rejeicao = 'id_substancia com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_substancia_raw !~ '^[0-9]+$';

UPDATE stg_substancia_sinonimo ss
SET status = 'rejeitado', motivo_rejeicao = 'substancia não encontrada'
WHERE ss.id_batch = :batch_id
  AND ss.status = 'pendente'
  AND NOT EXISTS (
      SELECT 1 FROM substancia s WHERE s.id = ss.id_substancia_raw::integer
  );

WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY lower(unaccent(btrim(sinonimo_raw)))
               ORDER BY id
           ) AS rn
      FROM stg_substancia_sinonimo
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_substancia_sinonimo ss
SET status = 'rejeitado', motivo_rejeicao = 'sinonimo duplicado no lote'
FROM duplicatas d
WHERE ss.id = d.id
  AND d.rn > 1;

UPDATE stg_substancia_sinonimo ss
SET status = 'rejeitado', motivo_rejeicao = 'sinonimo já cadastrado'
WHERE ss.id_batch = :batch_id
  AND ss.status = 'pendente'
  AND EXISTS (
      SELECT 1 FROM substancia_sinonimo x
      WHERE x.sinonimo_normalizado = lower(unaccent(btrim(ss.sinonimo_raw)))
  );

UPDATE stg_substancia_sinonimo
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';