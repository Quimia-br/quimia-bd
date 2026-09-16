-- MIGRATE — stg_classe_quimica → classe_quimica
-- Só migra o que já passou pela validação (status = 'ok').

INSERT INTO classe_quimica(nome, descricao)
SELECT
    btrim(nome_raw),
    NULLIF(btrim(descricao_raw), '')
FROM stg_classe_quimica
WHERE id_batch = :batch_id
    AND status = 'ok'
ON CONFLICT (nome) DO NOTHING;