UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'severidade vazia'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (severidade_raw IS NULL OR btrim(severidade_raw) = '');

UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'descricao_risco vazia'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (descricao_risco_raw IS NULL OR btrim(descricao_risco_raw) = '');

UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'severidade inválida'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND severidade_raw NOT IN ('baixa','media','alta','critica');

UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'lado A: precisa de substancia OU classe, não os dois nem nenhum'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      -- os dois vazios
      ((id_substancia_a_raw IS NULL OR btrim(id_substancia_a_raw) = '')
       AND (id_classe_a_raw IS NULL OR btrim(id_classe_a_raw) = ''))
      OR
      -- os dois preenchidos
      ((id_substancia_a_raw IS NOT NULL AND btrim(id_substancia_a_raw) <> '')
       AND (id_classe_a_raw IS NOT NULL AND btrim(id_classe_a_raw) <> ''))
  );

UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'lado B: precisa de substancia OU classe, não os dois nem nenhum'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      ((id_substancia_b_raw IS NULL OR btrim(id_substancia_b_raw) = '')
       AND (id_classe_b_raw IS NULL OR btrim(id_classe_b_raw) = ''))
      OR
      ((id_substancia_b_raw IS NOT NULL AND btrim(id_substancia_b_raw) <> '')
       AND (id_classe_b_raw IS NOT NULL AND btrim(id_classe_b_raw) <> ''))
  );

UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'id_substancia_a com formato inválido'
WHERE id_batch = :batch_id AND status = 'pendente'
  AND id_substancia_a_raw IS NOT NULL AND btrim(id_substancia_a_raw) <> ''
  AND id_substancia_a_raw !~ '^[0-9]+$';

UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'id_classe_a com formato inválido'
WHERE id_batch = :batch_id AND status = 'pendente'
  AND id_classe_a_raw IS NOT NULL AND btrim(id_classe_a_raw) <> ''
  AND id_classe_a_raw !~ '^[0-9]+$';

UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'id_substancia_b com formato inválido'
WHERE id_batch = :batch_id AND status = 'pendente'
  AND id_substancia_b_raw IS NOT NULL AND btrim(id_substancia_b_raw) <> ''
  AND id_substancia_b_raw !~ '^[0-9]+$';

UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'id_classe_b com formato inválido'
WHERE id_batch = :batch_id AND status = 'pendente'
  AND id_classe_b_raw IS NOT NULL AND btrim(id_classe_b_raw) <> ''
  AND id_classe_b_raw !~ '^[0-9]+$';

UPDATE stg_incompatibilidade_regra sir
SET status = 'rejeitado', motivo_rejeicao = 'substancia_a não encontrada'
WHERE sir.id_batch = :batch_id AND sir.status = 'pendente'
  AND sir.id_substancia_a_raw IS NOT NULL AND btrim(sir.id_substancia_a_raw) <> ''
  AND NOT EXISTS (SELECT 1 FROM substancia s WHERE s.id = sir.id_substancia_a_raw::integer);

UPDATE stg_incompatibilidade_regra sir
SET status = 'rejeitado', motivo_rejeicao = 'classe_a não encontrada'
WHERE sir.id_batch = :batch_id AND sir.status = 'pendente'
  AND sir.id_classe_a_raw IS NOT NULL AND btrim(sir.id_classe_a_raw) <> ''
  AND NOT EXISTS (SELECT 1 FROM classe_quimica c WHERE c.id = sir.id_classe_a_raw::integer);

UPDATE stg_incompatibilidade_regra sir
SET status = 'rejeitado', motivo_rejeicao = 'substancia_b não encontrada'
WHERE sir.id_batch = :batch_id AND sir.status = 'pendente'
  AND sir.id_substancia_b_raw IS NOT NULL AND btrim(sir.id_substancia_b_raw) <> ''
  AND NOT EXISTS (SELECT 1 FROM substancia s WHERE s.id = sir.id_substancia_b_raw::integer);

UPDATE stg_incompatibilidade_regra sir
SET status = 'rejeitado', motivo_rejeicao = 'classe_b não encontrada'
WHERE sir.id_batch = :batch_id AND sir.status = 'pendente'
  AND sir.id_classe_b_raw IS NOT NULL AND btrim(sir.id_classe_b_raw) <> ''
  AND NOT EXISTS (SELECT 1 FROM classe_quimica c WHERE c.id = sir.id_classe_b_raw::integer);

UPDATE stg_incompatibilidade_regra
SET status = 'rejeitado', motivo_rejeicao = 'ativo com formato inválido'
WHERE id_batch = :batch_id AND status = 'pendente'
  AND ativo_raw IS NOT NULL AND btrim(ativo_raw) <> ''
  AND lower(btrim(ativo_raw)) NOT IN ('true','false','t','f','1','0');

UPDATE stg_incompatibilidade_regra
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';