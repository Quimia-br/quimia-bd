UPDATE stg_produto
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');

UPDATE stg_produto
SET status = 'rejeitado', motivo_rejeicao = 'id_marca vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (id_marca_raw IS NULL OR btrim(id_marca_raw) = '');

UPDATE stg_produto
SET status = 'rejeitado', motivo_rejeicao = 'id_marca com formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_marca_raw !~ '^[0-9]+$';

UPDATE stg_produto sp
SET status = 'rejeitado', motivo_rejeicao = 'marca não encontrada'
WHERE sp.id_batch = :batch_id
  AND sp.status = 'pendente'
  AND NOT EXISTS (
      SELECT 1 FROM marca m WHERE m.id = sp.id_marca_raw::integer
  );

UPDATE stg_produto
SET status = 'rejeitado', motivo_rejeicao = 'tipo_produto inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND btrim(tipo_produto_raw) <> ''
  AND tipo_produto_raw IS NOT NULL
  AND tipo_produto_raw NOT IN (
      'limpeza_geral','desinfetante','desincrustante',
      'desengraxante','alvejante','aromatizante','outro'
  );


WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY btrim(cod_barras_raw) ORDER BY id) AS rn
      FROM stg_produto
     WHERE id_batch = :batch_id
       AND status = 'pendente'
       AND cod_barras_raw IS NOT NULL
       AND btrim(cod_barras_raw) <> ''
)
UPDATE stg_produto sp
SET status = 'rejeitado', motivo_rejeicao = 'cod_barras duplicado no lote'
FROM duplicatas d
WHERE sp.id = d.id
  AND d.rn > 1;

UPDATE stg_produto sp
SET status = 'rejeitado', motivo_rejeicao = 'cod_barras já cadastrado'
WHERE sp.id_batch = :batch_id
  AND sp.status = 'pendente'
  AND sp.cod_barras_raw IS NOT NULL
  AND btrim(sp.cod_barras_raw) <> ''
  AND EXISTS (
      SELECT 1 FROM produto p WHERE p.cod_barras = btrim(sp.cod_barras_raw)
  );

UPDATE stg_produto
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';