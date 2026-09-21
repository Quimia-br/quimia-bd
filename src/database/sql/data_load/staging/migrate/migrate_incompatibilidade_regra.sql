INSERT INTO incompatibilidade_regra (
    id_substancia_a, id_classe_a,
    id_substancia_b, id_classe_b,
    severidade, descricao_risco, fonte, ativo
)
SELECT
    NULLIF(btrim(id_substancia_a_raw), '')::integer,
    NULLIF(btrim(id_classe_a_raw), '')::integer,
    NULLIF(btrim(id_substancia_b_raw), '')::integer,
    NULLIF(btrim(id_classe_b_raw), '')::integer,
    btrim(severidade_raw),
    btrim(descricao_risco_raw),
    NULLIF(btrim(fonte_raw), ''),
    COALESCE(lower(btrim(ativo_raw)) IN ('true','t','1'), TRUE)
FROM stg_incompatibilidade_regra
WHERE id_batch = :batch_id
  AND status = 'ok';