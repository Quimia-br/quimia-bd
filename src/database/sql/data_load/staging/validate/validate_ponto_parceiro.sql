UPDATE stg_ponto_parceiro
SET status = 'rejeitado', motivo_rejeicao = 'id_empresa inválido (não numérico)'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_empresa_raw IS NOT NULL
  AND btrim(id_empresa_raw) <> ''
  AND NOT fn_inteiro_valido(id_empresa_raw);

UPDATE stg_ponto_parceiro sp
SET status = 'rejeitado', motivo_rejeicao = 'id_empresa não existe em empresa'
WHERE sp.id_batch = :batch_id
  AND sp.status = 'pendente'
  AND sp.id_empresa_raw IS NOT NULL
  AND btrim(sp.id_empresa_raw) <> ''
  AND NOT EXISTS (
      SELECT 1 FROM empresa e WHERE e.id = sp.id_empresa_raw::INTEGER
  );

UPDATE stg_ponto_parceiro
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');

UPDATE stg_ponto_parceiro
SET status = 'rejeitado', motivo_rejeicao = 'cep em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND cep_raw IS NOT NULL
  AND btrim(cep_raw) <> ''
  AND length(regexp_replace(cep_raw, '\D', '', 'g')) <> 8;

UPDATE stg_ponto_parceiro
SET status = 'rejeitado', motivo_rejeicao = 'estado não é uma sigla de UF válida'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND estado_raw IS NOT NULL
  AND btrim(estado_raw) <> ''
  AND upper(btrim(estado_raw)) NOT IN (
      'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA',
      'MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN',
      'RS','RO','RR','SC','SP','SE','TO'
  );

UPDATE stg_ponto_parceiro
SET status = 'rejeitado', motivo_rejeicao = 'numero inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND numero_raw IS NOT NULL
  AND btrim(numero_raw) <> ''
  AND NOT fn_inteiro_valido(numero_raw);

UPDATE stg_ponto_parceiro
SET status = 'rejeitado', motivo_rejeicao = 'tipo ausente ou fora do domínio permitido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      tipo_raw IS NULL
      OR lower(btrim(tipo_raw)) NOT IN ('compra', 'descarte')
  );

UPDATE stg_ponto_parceiro
SET status = 'rejeitado', motivo_rejeicao = 'ativo não é um booleano válido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND ativo_raw IS NOT NULL
  AND btrim(ativo_raw) <> ''
  AND lower(btrim(ativo_raw)) NOT IN ('true', 'false', 't', 'f', '1', '0');

UPDATE stg_ponto_parceiro
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';