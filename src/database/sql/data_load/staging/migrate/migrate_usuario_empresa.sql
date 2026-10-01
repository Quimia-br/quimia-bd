INSERT INTO usuario (nome, email, data_nasc, foto_url, senha, nivel_acesso, ultima_sessao)
SELECT
    btrim(nome_raw),
    lower(btrim(email_raw)),
    NULLIF(btrim(data_nasc_raw), '')::date,
    NULLIF(btrim(foto_url_raw), ''),
    btrim(senha_raw),
    lower(btrim(nivel_acesso_raw)),
    NULLIF(btrim(ultima_sessao_raw), '')::timestamptz
FROM stg_usuario
WHERE id_batch = :batch_id
  AND status = 'ok';

  
INSERT INTO empresa (nome, email, cnpj, senha, foto_url, ativo)
SELECT
    btrim(nome_raw),
    lower(btrim(email_raw)),
    cnpj_raw,
    btrim(senha_raw),
    NULLIF(btrim(foto_url_raw), ''),
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