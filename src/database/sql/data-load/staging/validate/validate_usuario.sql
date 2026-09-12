-- ============================================================
-- VALIDATE — stg_usuario
-- Roda após o COPY bruto. Parâmetro :batch_id (UUID) do lote.
-- Cada UPDATE marca 'rejeitado' com motivo específico;
-- o que sobrar pendente no final vira 'ok'.
-- ============================================================

-- 1) nome vazio
UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'nome vazio'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (nome_raw IS NULL OR btrim(nome_raw) = '');

-- 2) email em formato inválido
UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'email em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (
      email_raw IS NULL
      OR btrim(email_raw) = ''
      OR email_raw !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'
  );

-- 3) email duplicado dentro do próprio lote
--    (window function: mantém a 1ª ocorrência como candidata a 'ok',
--     rejeita as demais explicitamente)
WITH duplicatas AS (
    SELECT id,
           ROW_NUMBER() OVER (PARTITION BY lower(btrim(email_raw)) ORDER BY id) AS rn
      FROM stg_usuario
     WHERE id_batch = :batch_id
       AND status = 'pendente'
)
UPDATE stg_usuario su
SET status = 'rejeitado', motivo_rejeicao = 'email duplicado no lote'
FROM duplicatas d
WHERE su.id = d.id
  AND d.rn > 1;

-- 4) email já existe na tabela final (não é erro de lote, é conflito com o banco)
UPDATE stg_usuario su
SET status = 'rejeitado', motivo_rejeicao = 'email já cadastrado'
WHERE su.id_batch = :batch_id
  AND su.status = 'pendente'
  AND EXISTS (
      SELECT 1 FROM usuario u WHERE lower(u.email) = lower(btrim(su.email_raw))
  );

-- 5) data_nasc malformada (aceita vazio — coluna é nullable)
UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'data_nasc inválida'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND data_nasc_raw IS NOT NULL
  AND btrim(data_nasc_raw) <> ''
  AND NOT fn_data_valida(data_nasc_raw);

-- 6) nivel_acesso fora do enum
UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'nivel_acesso fora do domínio permitido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND lower(btrim(nivel_acesso_raw)) NOT IN ('usuario', 'empresa', 'admin');

-- 7) ultima_sessao malformada (aceita vazio — coluna é nullable)
UPDATE stg_usuario
SET status = 'rejeitado', motivo_rejeicao = 'ultima_sessao inválida'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND NOT fn_timestamp_valido(ultima_sessao_raw);

-- 8) o que sobrou pendente está limpo
UPDATE stg_usuario
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';
