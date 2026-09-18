-- MIGRATE — stg_substancia_sinonimo → substancia_sinonimo
-- Só migra o que já passou pela validação (status = 'ok').

INSERT INTO substancia_sinonimo (id_substancia, sinonimo, sinonimo_normalizado)
SELECT
    id_substancia_raw::integer,
    btrim(sinonimo_raw),
    lower(unaccent(btrim(sinonimo_raw)))
FROM stg_substancia_sinonimo
WHERE id_batch = :batch_id
  AND status = 'ok';