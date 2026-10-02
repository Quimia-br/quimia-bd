INSERT INTO produto (nome, id_marca, descricao, tipo_produto, cod_barras, foto_url)
SELECT
    btrim(nome_raw),
    id_marca_raw::integer,
    NULLIF(btrim(descricao_raw), ''),
    NULLIF(btrim(tipo_produto_raw), ''),
    NULLIF(btrim(cod_barras_raw), ''),
    NULLIF(btrim(foto_url_raw), '')
FROM stg_produto
WHERE id_batch = :batch_id
  AND status = 'ok';