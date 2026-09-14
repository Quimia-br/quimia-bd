-- MIGRATE — stg_superficie → superficie
-- Só migra o que já passou pela validação (status = 'ok').

INSERT INTO superficie (nome, descricao)
SELECT
    btrim(nome_raw),
    NULLIF(btrim(descricao_raw), '')
FROM stg_superficie
WHERE id_batch = :batch_id
  AND status = 'ok';