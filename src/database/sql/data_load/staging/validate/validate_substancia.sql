-- VALIDATE — stg_substancia
-- Roda após o COPY bruto. Parâmetro :batch_id (UUID) do lote.
-- cas_numero é NULLABLE (nem todo composto tem CAS) mas UNIQUE
-- quando preenchido — validação só entra em ação com valor presente.

UPDATE stg_substancia
SET status = 'rejeitado', motivo_rejeicao = 'nome_canonico vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_canonico_raw IS NULL OR btrim(nome_canonico_raw) = '');


UPDATE stg_substancia
SET status = 'rejeitado', motivo_rejeicao = 'cas_numero em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND cas_numero_raw IS NOT NULL
  AND btrim(cas_numero_raw) <> ''
  AND cas_numero_raw !~ '^\d{2,7}-\d{2}-\d$';

WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY btrim(cas_numero_raw) ORDER BY id) AS rn
      FROM stg_substancia
     WHERE id_batch = :batch_id
       AND status = 'pendente'
       AND cas_numero_raw IS NOT NULL
       AND btrim(cas_numero_raw) <> ''
)
UPDATE stg_substancia ss
SET status = 'rejeitado', motivo_rejeicao = 'cas_numero duplicado no lote'
FROM duplicatas d
WHERE ss.id = d.id
  AND d.rn > 1;

UPDATE stg_substancia ss
SET status = 'rejeitado', motivo_rejeicao = 'cas_numero já cadastrado'
WHERE ss.id_batch = :batch_id
  AND ss.status = 'pendente'
  AND ss.cas_numero_raw IS NOT NULL
  AND btrim(ss.cas_numero_raw) <> ''
  AND EXISTS (
      SELECT 1 FROM substancia s WHERE s.cas_numero = btrim(ss.cas_numero_raw)
  );

UPDATE stg_substancia ss
SET status = 'rejeitado', motivo_rejeicao = 'nome_canonico (sem CAS) já cadastrado'
WHERE ss.id_batch = :batch_id
  AND ss.status = 'pendente'
  AND (ss.cas_numero_raw IS NULL OR btrim(ss.cas_numero_raw) = '')
  AND EXISTS (
      SELECT 1 FROM substancia s
       WHERE s.cas_numero IS NULL
         AND lower(s.nome_canonico) = lower(btrim(ss.nome_canonico_raw))
  );

WITH duplicatas_nome AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY lower(btrim(nome_canonico_raw)) ORDER BY id) AS rn
      FROM stg_substancia
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_substancia ss
SET status = 'rejeitado', motivo_rejeicao = 'nome_canonico duplicado no lote'
FROM duplicatas_nome d
WHERE ss.id = d.id
  AND d.rn > 1;

UPDATE stg_substancia
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';