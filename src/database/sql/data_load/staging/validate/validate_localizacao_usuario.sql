UPDATE stg_localizacao_usuario
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario ausente'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (id_usuario_raw IS NULL OR btrim(id_usuario_raw) = '');


UPDATE stg_localizacao_usuario
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario não é um UUID válido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_usuario_raw !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';


UPDATE stg_localizacao_usuario su
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario não existe em usuario'
WHERE su.id_batch = :batch_id
  AND su.status = 'pendente'
  AND NOT EXISTS (
      SELECT 1 FROM usuario u WHERE u.id = su.id_usuario_raw::UUID
  );

WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY id_usuario_raw ORDER BY id) AS rn
      FROM stg_localizacao_usuario
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_localizacao_usuario su
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario duplicado no lote'
FROM duplicatas d
WHERE su.id = d.id
  AND d.rn > 1;

UPDATE stg_localizacao_usuario su
SET status = 'rejeitado', motivo_rejeicao = 'usuário já possui localização cadastrada'
WHERE su.id_batch = :batch_id
  AND su.status = 'pendente'
  AND EXISTS (
      SELECT 1 FROM localizacao_usuario lu WHERE lu.id_usuario = su.id_usuario_raw::UUID
  );

UPDATE stg_localizacao_usuario
SET status = 'rejeitado', motivo_rejeicao = 'cep em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      cep_raw IS NULL
      OR btrim(cep_raw) = ''
      OR length(regexp_replace(cep_raw, '\D', '', 'g')) <> 8
  );

UPDATE stg_localizacao_usuario
SET status = 'rejeitado', motivo_rejeicao = 'estado não é uma sigla de UF válida'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      estado_raw IS NULL
      OR btrim(estado_raw) = ''
      OR upper(btrim(estado_raw)) !~ '^[A-Z]{2}$'
      OR upper(btrim(estado_raw)) NOT IN (
          'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA',
          'MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN',
          'RS','RO','RR','SC','SP','SE','TO'
      )
  );

UPDATE stg_localizacao_usuario
SET status = 'rejeitado', motivo_rejeicao = 'numero inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND numero_raw IS NOT NULL
  AND btrim(numero_raw) <> ''
  AND NOT fn_inteiro_valido(numero_raw);

UPDATE stg_localizacao_usuario
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';