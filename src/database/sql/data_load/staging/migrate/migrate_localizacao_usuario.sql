-- MIGRATE — stg_localizacao_usuario → localizacao_usuario
-- Só migra o que já passou pela validação (status = 'ok').
-- id_usuario é UUID; cast explícito na migração.

INSERT INTO localizacao_usuario (
    id_usuario,
    cep,
    estado,
    bairro,
    rua,
    numero,
    complemento
)
SELECT
    id_usuario_raw::UUID,
    regexp_replace(cep_raw, '\D', '', 'g'),   -- normaliza: só dígitos
    upper(btrim(estado_raw)),
    btrim(bairro_raw),
    btrim(rua_raw),
    NULLIF(btrim(numero_raw), '')::INTEGER,
    NULLIF(btrim(complemento_raw), '')
FROM stg_localizacao_usuario
WHERE id_batch = :batch_id
  AND status = 'ok'
ON CONFLICT (id_usuario) DO NOTHING;  -- upsert simples; id_usuario é UNIQUE na tabela final