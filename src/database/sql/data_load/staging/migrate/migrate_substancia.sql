-- MIGRATE — stg_substancia → substancia
-- Só migra o que já passou pela validação (status = 'ok').
-- cas_numero fica NULL quando não informado.


INSERT INTO substancia (nome_canonico, cas_numero, descricao)
SELECT
    btrim(nome_canonico_raw),
    NULLIF(btrim(cas_numero_raw), ''),
    NULLIF(btrim(descricao_raw), '')
FROM stg_substancia
WHERE id_batch = :batch_id
  AND status = 'ok'
ON CONFLICT (cas_numero) DO NOTHING;  -- cas_numero é UNIQUE (quando preenchido)
-- ATENÇÃO: ON CONFLICT(cas_numero) não protege contra duplicata de
-- substâncias SEM cas_numero (NULL não conflita com NULL em UNIQUE).
-- Isso já é coberto na validação (checagem de nome_canonico duplicado
-- no lote), mas não há proteção contra duplicata entre lotes diferentes
-- para substâncias sem CAS — ex: rodar "Fragrância" duas vezes em CSVs
-- separados cria duas linhas. Vale decisão do time se isso precisa de
-- tratamento adicional (ex: checar nome_canonico também na migração).