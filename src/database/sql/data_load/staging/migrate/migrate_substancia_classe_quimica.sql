-- MIGRATE — stg_substancia_classe_quimica → substancia_classe_quimica
-- Só migra o que já passou pela validação (status = 'ok').

INSERT INTO substancia_classe_quimica (id_substancia, id_classe_quimica)
SELECT
    id_substancia_raw::integer,
    id_classe_quimica_raw::integer
FROM stg_substancia_classe_quimica
WHERE id_batch = :batch_id
  AND status = 'ok';