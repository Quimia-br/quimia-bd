-- VALIDATE — stg_classe_quimica
-- Roda após o COPY bruto. Parâmetro :batch_id (UUID) do lote.
-- classe_quimica.nome É UNIQUE no schema oficial — checagem aqui
-- reflete constraint real do banco, não é decisão só de qualidade.

UPDATE stg_classe_quimica
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');

WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY lower(btrim(nome_raw)) ORDER BY id) AS rn
      FROM stg_classe_quimica
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_classe_quimica sc
SET status = 'rejeitado', motivo_rejeicao = 'nome duplicado no lote'
FROM duplicatas d
WHERE sc.id = d.id
  AND d.rn > 1;

UPDATE stg_classe_quimica sc
SET status = 'rejeitado', motivo_rejeicao = 'classe química já cadastrada'
WHERE sc.id_batch = :batch_id
  AND sc.status = 'pendente'
  AND EXISTS (
      SELECT 1 FROM classe_quimica c WHERE lower(c.nome) = lower(btrim(sc.nome_raw))
  );

UPDATE stg_classe_quimica
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';