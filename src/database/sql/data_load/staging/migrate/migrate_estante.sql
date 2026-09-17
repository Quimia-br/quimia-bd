-- MIGRATE tabela stg_estante -> estante
-- Migra o que status = 'ok'

INSERT INTO estante(id_usuario, nome, ambiente)
SELECT
    id_usuario_raw::uuid,
    btrim(nome_raw),
    NULLIF(btrim(ambiente_raw), '')
FROM stg_estante
WHERE id_batch = :batch_id
  AND status = 'ok';
