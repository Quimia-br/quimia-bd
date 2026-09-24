INSERT INTO historico_recomendacao (id_produto, id_usuario, resultado, dosagem_sugerida)
SELECT
    id_produto_raw::integer,
    id_usuario_raw::uuid,
    NULLIF(btrim(resultado_raw), ''),
    NULLIF(btrim(dosagem_sugerida_raw), '')
FROM stg_historico_recomendacao
WHERE id_batch = :batch_id
  AND status = 'ok';