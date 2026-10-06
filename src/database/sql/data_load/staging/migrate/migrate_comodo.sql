INSERT INTO comodo(id_usuario, nome, icone_comodo)
SELECT
    id_usuario_raw::uuid,
    btrim(nome_raw),
    NULLIF(btrim(icone_comodo_raw), '')
FROM stg_comodo
WHERE id_batch = :batch_id
  AND status = 'ok';
