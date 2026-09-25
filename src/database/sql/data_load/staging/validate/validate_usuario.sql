UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');


UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'email em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      email_raw IS NULL
      OR btrim(email_raw) = ''
      OR email_raw !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
  );

WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY lower(btrim(email_raw)) ORDER BY id) AS rn
      FROM stg_usuario
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_usuario su
SET status = 'rejeitado', motivo_rejeicao = 'email duplicado no lote'
FROM duplicatas d
WHERE su.id = d.id
  AND d.rn > 1;

UPDATE stg_usuario su
SET status = 'rejeitado', motivo_rejeicao = 'email já cadastrado'
WHERE su.id_batch = :batch_id
  AND su.status = 'pendente'
  AND EXISTS (
      SELECT 1 FROM usuario u WHERE lower(u.email) = lower(btrim(su.email_raw))
  );


UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'senha vazia ou com formato inválido (esperado hash bcrypt de 60 caracteres)'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      senha_raw IS NULL
      OR btrim(senha_raw) = ''
      OR LENGTH(btrim(senha_raw)) <> 60
  );

UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'foto_url com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND foto_url_raw IS NOT NULL
  AND btrim(foto_url_raw) <> ''
  AND foto_url_raw !~* '^https?://';

UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'data_nasc inválida'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND data_nasc_raw IS NOT NULL
  AND btrim(data_nasc_raw) <> ''
  AND NOT fn_data_valida(data_nasc_raw);

UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'nivel_acesso fora do domínio permitido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND( 
  nivel_acesso_raw IS NULL
  OR lower(btrim(nivel_acesso_raw)) NOT IN ('usuario', 'empresa', 'admin')
  );


UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'ultima_sessao inválida'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND NOT fn_timestamp_valido(ultima_sessao_raw);


UPDATE stg_usuario
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';