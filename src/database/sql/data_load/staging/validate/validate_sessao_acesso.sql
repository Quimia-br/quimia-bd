-- 1. id_usuario ausente ou vazio (NOT NULL na tabela final)
UPDATE stg_sessao_acesso
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario ausente'
WHERE id_batch = :batch_id
  AND (id_usuario_raw IS NULL OR btrim(id_usuario_raw) = '');

-- 2. id_usuario em formato inválido (não é um UUID)
UPDATE stg_sessao_acesso
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_usuario_raw !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

-- 3. id_usuario não existe na tabela usuario (FK órfã)
UPDATE stg_sessao_acesso s
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario inexistente'
WHERE s.id_batch = :batch_id
  AND s.status = 'pendente'
  AND CASE WHEN s.status = 'pendente'
           THEN NOT EXISTS (SELECT 1 FROM usuario u WHERE u.id = s.id_usuario_raw::uuid)
           ELSE false
      END;

-- 4. ocorreu_em ausente ou vazia (NOT NULL na tabela final; não vale cair no
--    DEFAULT now(), senão o lote inteiro viraria "hoje" e distorceria o DAU)
UPDATE stg_sessao_acesso
SET status = 'rejeitado', motivo_rejeicao = 'ocorreu_em ausente'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (ocorreu_em_raw IS NULL OR btrim(ocorreu_em_raw) = '');

-- 5. ocorreu_em em formato inválido (esperado: ISO 8601, ex. 2026-10-03T08:15:22-03:00).
--    Além do formato, checa se o dia existe no mês (31/02 passa na regex, mas
--    estouraria o cast adiante).
UPDATE stg_sessao_acesso
SET status = 'rejeitado', motivo_rejeicao = 'ocorreu_em em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND NOT CASE
      WHEN ocorreu_em_raw ~ '^(19|20)[0-9]{2}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])[T ]([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]+)?(Z|[+-]([01][0-9]|2[0-3]):?[0-5][0-9])?$'
      THEN substring(ocorreu_em_raw FROM 9 FOR 2)::int
           <= EXTRACT(day FROM (
                make_date(substring(ocorreu_em_raw FROM 1 FOR 4)::int,
                          substring(ocorreu_em_raw FROM 6 FOR 2)::int, 1)
                + interval '1 month - 1 day'))
      ELSE false
  END;

-- 6. ocorreu_em no futuro (um login não pode ter acontecido depois de agora)
UPDATE stg_sessao_acesso
SET status = 'rejeitado', motivo_rejeicao = 'ocorreu_em no futuro'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND CASE WHEN status = 'pendente'
           THEN ocorreu_em_raw::timestamptz > now()
           ELSE false
      END;

-- 7. sessão duplicada no lote (mesmo usuário + mesmo instante, comparando já
--    convertido: 08:00-03:00 e 11:00Z são o mesmo instante)
WITH duplicados AS (
    SELECT ctid,
           ROW_NUMBER() OVER (
               PARTITION BY id_usuario_raw::uuid, ocorreu_em_raw::timestamptz
               ORDER BY ctid
           ) AS rn
    FROM stg_sessao_acesso
    WHERE id_batch = :batch_id
      AND status = 'pendente'
)
UPDATE stg_sessao_acesso s
SET status = 'rejeitado', motivo_rejeicao = 'sessão duplicada no lote (mesmo usuário e instante)'
FROM duplicados d
WHERE s.ctid = d.ctid
  AND d.rn > 1;

-- 8. o que sobrou passou em tudo
UPDATE stg_sessao_acesso
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';