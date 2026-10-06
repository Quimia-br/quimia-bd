INSERT INTO sessao_acesso (id_usuario, ocorreu_em)
SELECT
    id_usuario_raw::uuid,
    ocorreu_em_raw::timestamptz
FROM stg_sessao_acesso
WHERE id_batch = :batch_id
  AND status = 'ok'
ORDER BY ocorreu_em_raw::timestamptz;