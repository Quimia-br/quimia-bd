-- VALIDATE — stg_marca
-- Roda após o COPY bruto. Parâmetro :batch_id (UUID) do lote.

UPDATE stg_marca
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');


WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY lower(btrim(nome_raw)) ORDER BY id) AS rn
      FROM stg_marca
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_marca sm
SET status = 'rejeitado', motivo_rejeicao = 'nome duplicado no lote'
FROM duplicatas d
WHERE sm.id = d.id
  AND d.rn > 1;

UPDATE stg_marca sm
SET status = 'rejeitado', motivo_rejeicao = 'marca já cadastrada'
WHERE sm.id_batch = :batch_id
  AND sm.status = 'pendente'
  AND EXISTS (
      SELECT 1 FROM marca m WHERE lower(m.nome) = lower(btrim(sm.nome_raw))
  );

UPDATE stg_marca
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';