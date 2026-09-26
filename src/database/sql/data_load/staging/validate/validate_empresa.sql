UPDATE stg_empresa
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');

UPDATE stg_empresa
SET status = 'rejeitado', motivo_rejeicao = 'email em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      email_raw IS NULL
      OR btrim(email_raw) = ''
      OR email_raw !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
  );

UPDATE stg_empresa
SET status = 'rejeitado', motivo_rejeicao = 'senha vazia ou com formato inválido (esperado hash bcrypt de 60 caracteres)'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      senha_raw IS NULL
      OR btrim(senha_raw) = ''
      OR LENGTH(btrim(senha_raw)) <> 60
  );

UPDATE stg_empresa
SET status = 'rejeitado', motivo_rejeicao = 'foto_url com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND foto_url_raw IS NOT NULL
  AND btrim(foto_url_raw) <> ''
  AND foto_url_raw !~* '^https?://';

WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY btrim(cnpj_raw) ORDER BY id) AS rn
      FROM stg_empresa
     WHERE id_batch = :batch_id
       AND status = 'pendente'
       AND cnpj_raw IS NOT NULL
       AND btrim(cnpj_raw) <> ''
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
  AND se.cnpj_raw IS NOT NULL
  AND btrim(se.cnpj_raw) <> ''
  AND EXISTS (
      SELECT 1 FROM empresa e WHERE e.cnpj = btrim(se.cnpj_raw)
  );

UPDATE stg_empresa
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';