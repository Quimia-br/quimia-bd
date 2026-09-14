-- MIGRATE — stg_marca → marca
-- Só migra o que já passou pela validação (status = 'ok').

INSERT INTO marca (nome)
SELECT btrim(nome_raw)
FROM stg_marca
WHERE id_batch = :batch_id
  AND status = 'ok';
