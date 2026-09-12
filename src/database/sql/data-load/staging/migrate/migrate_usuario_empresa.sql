INSERT INTO usuario (nome, email, data_nasc, nivel_acesso, ultima_sessao)
SELECT
    btrim(nome_raw),
    lower(btrim(email_raw)),
    NULLIF(btrim(data_nasc_raw), '')::DATE,
    lower(btrim(nivel_acesso_raw)),
    NULLIF(btrim(ultima_sessao_raw), '')::TIMESTAMP
FROM stg_usuario
WHERE id_batch = :batch_id
  AND status = 'ok'
ON CONFLICT (email) DO NOTHING;


INSERT INTO empresa (nome, cnpj, ativo)
SELECT
    btrim(nome_raw),
    cnpj_raw,
    CASE lower(btrim(ativo_raw))
        WHEN 'true' THEN TRUE
        WHEN 't'    THEN TRUE
        WHEN '1'    THEN TRUE
        WHEN 'false' THEN FALSE
        WHEN 'f'     THEN FALSE
        WHEN '0'     THEN FALSE
        ELSE TRUE
    END
FROM stg_empresa
WHERE id_batch = :batch_id
  AND status = 'ok'
ON CONFLICT (cnpj) DO NOTHING;
