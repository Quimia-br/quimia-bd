-- VALIDATE — stg_superficie
-- Roda após o COPY bruto. Parâmetro :batch_id (UUID) do lote.


UPDATE stg_superficie
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');


WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY lower(btrim(nome_raw)) ORDER BY id) AS rn
      FROM stg_superficie
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_superficie ss
SET status = 'rejeitado', motivo_rejeicao = 'nome duplicado no lote'
FROM duplicatas d
WHERE ss.id = d.id
  AND d.rn > 1;

UPDATE stg_superficie ss
SET status = 'rejeitado', motivo_rejeicao = 'superfície já cadastrada'
WHERE ss.id_batch = :batch_id
  AND ss.status = 'pendente'
  AND EXISTS (
      SELECT 1 FROM superficie s WHERE lower(s.nome) = lower(btrim(ss.nome_raw))
  );

UPDATE stg_superficie
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';