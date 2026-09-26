CREATE OR REPLACE FUNCTION fn_sincronizar_catalogo()
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_obj RECORD;
    v_col RECORD;
    v_id  INTEGER;
BEGIN
    FOR v_obj IN
        SELECT c.oid,
               c.relname AS nome,
               CASE c.relkind WHEN 'r' THEN 'tabela' ELSE 'view' END AS tipo,
               obj_description(c.oid, 'pg_class') AS comentario
          FROM pg_class c
          JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE n.nspname = 'public'
           AND c.relkind IN ('r', 'v')
           AND c.relname NOT LIKE 'stg\_%'
           AND c.relname <> 'flyway_schema_history'
    LOOP
        INSERT INTO catalogo_tabela (nome_tabela, tipo_objeto, descricao, atualizado_em)
        VALUES (v_obj.nome, v_obj.tipo, v_obj.comentario, now())
        ON CONFLICT (nome_tabela) DO UPDATE
            SET tipo_objeto   = EXCLUDED.tipo_objeto,
                descricao     = COALESCE(EXCLUDED.descricao, catalogo_tabela.descricao),
                atualizado_em = now()
        RETURNING id INTO v_id;

        FOR v_col IN
            SELECT a.attname,
                   format_type(a.atttypid, a.atttypmod) AS tipo,
                   a.attnotnull,
                   col_description(v_obj.oid, a.attnum) AS comentario,
                   EXISTS (
                       SELECT 1 FROM pg_constraint k
                        WHERE k.conrelid = v_obj.oid AND k.contype = 'p'
                          AND a.attnum = ANY (k.conkey)
                   ) AS pk,
                   (SELECT cf.relname
                      FROM pg_constraint k
                      JOIN pg_class cf ON cf.oid = k.confrelid
                     WHERE k.conrelid = v_obj.oid AND k.contype = 'f'
                       AND a.attnum = ANY (k.conkey)
                     LIMIT 1) AS fk_tabela
              FROM pg_attribute a
             WHERE a.attrelid = v_obj.oid
               AND a.attnum > 0
               AND NOT a.attisdropped
        LOOP
            INSERT INTO catalogo_coluna (
                id_catalogo_tabela, nome_coluna, tipo_dado, obrigatorio,
                chave_primaria, referencia_tabela, descricao_negocio
            ) VALUES (
                v_id, v_col.attname, v_col.tipo, v_col.attnotnull,
                v_col.pk, v_col.fk_tabela, v_col.comentario
            )
            ON CONFLICT (id_catalogo_tabela, nome_coluna) DO UPDATE
                SET tipo_dado         = EXCLUDED.tipo_dado,
                    obrigatorio       = EXCLUDED.obrigatorio,
                    chave_primaria    = EXCLUDED.chave_primaria,
                    referencia_tabela = EXCLUDED.referencia_tabela,
                    descricao_negocio = COALESCE(EXCLUDED.descricao_negocio, catalogo_coluna.descricao_negocio);
        END LOOP;

        -- colunas que deixaram de existir
        DELETE FROM catalogo_coluna cc
         WHERE cc.id_catalogo_tabela = v_id
           AND NOT EXISTS (
               SELECT 1 FROM pg_attribute a
                WHERE a.attrelid = v_obj.oid AND a.attname = cc.nome_coluna
                  AND a.attnum > 0 AND NOT a.attisdropped
           );
    END LOOP;

    -- tabelas/views que deixaram de existir
    DELETE FROM catalogo_tabela ct
     WHERE NOT EXISTS (
         SELECT 1 FROM pg_class c
         JOIN pg_namespace n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = ct.nome_tabela
          AND c.relkind IN ('r', 'v')
          AND c.relname NOT LIKE 'stg\_%'
          AND c.relname <> 'flyway_schema_history'
     );
END;
$$;

COMMENT ON FUNCTION fn_sincronizar_catalogo() IS 'Sincroniza catalogo_tabela e catalogo_coluna com o pg_catalog (estrutura e COMMENT ON). Idempotente; nunca sobrescreve domínio, nível de acesso, responsável, regra de negócio nem a marcação LGPD.';
