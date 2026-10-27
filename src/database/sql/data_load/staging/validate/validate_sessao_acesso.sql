UPDATE stg_sessao_acesso
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario ausente'
WHERE id_batch = :batch_id
  AND (id_usuario_raw IS NULL OR btrim(id_usuario_raw) = '');

UPDATE stg_sessao_acesso
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario em formato inválido'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND id_usuario_raw !~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$';

UPDATE stg_sessao_acesso s
SET status = 'rejeitado', motivo_rejeicao = 'id_usuario inexistente'
WHERE s.id_batch = :batch_id
  AND s.status = 'pendente'
  AND CASE WHEN s.status = 'pendente'
           THEN NOT EXISTS (SELECT 1 FROM usuario u WHERE u.id = s.id_usuario_raw::uuid)
           ELSE false
      END;

UPDATE stg_sessao_acesso
SET status = 'rejeitado', motivo_rejeicao = 'ocorreu_em ausente'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND (ocorreu_em_raw IS NULL OR btrim(ocorreu_em_raw) = '');


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

UPDATE stg_sessao_acesso
SET status = 'rejeitado', motivo_rejeicao = 'ocorreu_em no futuro'
WHERE id_batch = :batch_id
  AND status = 'pendente'
  AND CASE WHEN status = 'pendente'
           THEN ocorreu_em_raw::timestamptz > now()
           ELSE false
      END;


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

UPDATE stg_sessao_acesso s
SET status = 'rejeitado', motivo_rejeicao = 'sessão já cadastrada (mesmo usuário e instante)'
WHERE s.id_batch = :batch_id
  AND s.status = 'pendente'
  AND CASE WHEN s.status = 'pendente'
           THEN EXISTS (
                    SELECT 1 FROM sessao_acesso sa
                    WHERE sa.id_usuario = s.id_usuario_raw::uuid
                      AND sa.ocorreu_em = s.ocorreu_em_raw::timestamptz)
           ELSE false
      END;


UPDATE stg_sessao_acesso
SET status = 'ok'
WHERE id_batch = :batch_id
  AND status = 'pendente';