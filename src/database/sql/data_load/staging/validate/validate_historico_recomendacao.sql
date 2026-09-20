UPDATE stg_historico_recomendacao
SET status = 'rejeitado', motivo_rejeicao = 'id_produto vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (id_produto_raw IS NULL OR btrim(id_produto_raw) = '');

UPDATE stg_historico_recomendacao
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (id_usuario_raw IS NULL OR btrim(id_usuario_raw) = '');

UPDATE stg_historico_recomendacao
SET status = 'rejeitado', motivo_rejeicao = 'id_produto com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_produto_raw !~ '^[0-9]+$';

UPDATE stg_historico_recomendacao
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_usuario_raw !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

UPDATE stg_historico_recomendacao
SET status = 'rejeitado', motivo_rejeicao = 'id_superficie com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_superficie_raw IS NOT NULL
  AND btrim(id_superficie_raw) <> ''
  AND id_superficie_raw !~ '^[0-9]+$';

UPDATE stg_historico_recomendacao shr
SET status = 'rejeitado', motivo_rejeicao = 'produto não encontrado'
WHERE shr.id_batch = :batch_id
  AND shr.status = 'pendente'
  AND NOT EXISTS (
      SELECT 1 FROM produto p WHERE p.id = shr.id_produto_raw::integer
  );

UPDATE stg_historico_recomendacao shr
SET status = 'rejeitado', motivo_rejeicao = 'usuario não encontrado'
WHERE shr.id_batch = :batch_id
  AND shr.status = 'pendente'
  AND NOT EXISTS (
      SELECT 1 FROM usuario u WHERE u.id = shr.id_usuario_raw::uuid
  );

UPDATE stg_historico_recomendacao shr
SET status = 'rejeitado', motivo_rejeicao = 'superficie não encontrada'
WHERE shr.id_batch = :batch_id
  AND shr.status = 'pendente'
  AND shr.id_superficie_raw IS NOT NULL
  AND btrim(shr.id_superficie_raw) <> ''
  AND NOT EXISTS (
      SELECT 1 FROM superficie s WHERE s.id = shr.id_superficie_raw::integer
  );

UPDATE stg_historico_recomendacao
SET status = 'rejeitado', motivo_rejeicao = 'resultado inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND resultado_raw IS NOT NULL
  AND btrim(resultado_raw) <> ''
  AND resultado_raw NOT IN ('compativel','incompativel','atencao','nao_avaliado');

UPDATE stg_historico_recomendacao
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';