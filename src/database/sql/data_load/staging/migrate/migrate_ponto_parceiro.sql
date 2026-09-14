-- MIGRATE — stg_ponto_parceiro → ponto_parceiro
-- Só migra o que já passou pela validação (status = 'ok').
-- id_empresa é nullable (ponto público sem empresa vinculada).

INSERT INTO ponto_parceiro (
    id_empresa,
    nome,
    cep,
    estado,
    bairro,
    rua,
    numero,
    complemento,
    tipo,
    ativo
)
SELECT
    NULLIF(btrim(id_empresa_raw), '')::INTEGER,
    btrim(nome_raw),
    NULLIF(regexp_replace(COALESCE(cep_raw, ''), '\D', '', 'g'), ''),
    NULLIF(upper(btrim(estado_raw)), ''),
    NULLIF(btrim(bairro_raw), ''),
    NULLIF(btrim(rua_raw), ''),
    NULLIF(btrim(numero_raw), '')::INTEGER,
    NULLIF(btrim(complemento_raw), ''),
    lower(btrim(tipo_raw)),
    CASE lower(btrim(COALESCE(ativo_raw, '')))
        WHEN 'true'  THEN TRUE
        WHEN 't'     THEN TRUE
        WHEN '1'     THEN TRUE
        WHEN 'false' THEN FALSE
        WHEN 'f'     THEN FALSE
        WHEN '0'     THEN FALSE
        ELSE TRUE
    END
FROM stg_ponto_parceiro
WHERE id_batch = :batch_id
  AND status = 'ok';