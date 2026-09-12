-- ============================================================
-- VALIDATE — stg_empresa
-- Roda após o COPY bruto. Parâmetro :batch_id (UUID) do lote.
-- ============================================================

UPDATE stg_empresa
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');

UPDATE stg_empresa
SET status = 'rejeitado', motivo_rejeicao = 'cnpj em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      cnpj_raw IS NULL
      OR btrim(cnpj_raw) = ''
      OR length(regexp_replace(cnpj_raw, '\D', '', 'g')) <> 14
  );

UPDATE stg_empresa
SET status = 'rejeitado', motivo_rejeicao = 'cnpj inválido (todos os dígitos iguais)'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND regexp_replace(cnpj_raw, '\D', '', 'g') ~ '^(\d)\1{13}$';

WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY regexp_replace(cnpj_raw, '\D', '', 'g')
               ORDER BY id
           ) AS rn
      FROM stg_empresa
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_empresa se
SET status = 'rejeitado', motivo_rejeicao = 'cnpj duplicado no lote'
FROM duplicatas d
WHERE se.id = d.id
  AND d.rn > 1;

UPDATE stg_empresa se
SET status = 'rejeitado', motivo_rejeicao = 'cnpj já cadastrado'
WHERE se.id_batch = :batch_id
  AND se.status = 'pendente'
  AND EXISTS (
      SELECT 1 FROM empresa e
      WHERE regexp_replace(e.cnpj, '\D', '', 'g') = regexp_replace(se.cnpj_raw, '\D', '', 'g')
  );

UPDATE stg_empresa
SET status = 'rejeitado', motivo_rejeicao = 'ativo não é um booleano válido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND lower(btrim(ativo_raw)) NOT IN ('true', 'false', 't', 'f', '1', '0', '');

UPDATE stg_empresa
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';
