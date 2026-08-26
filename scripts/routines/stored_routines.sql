DROP TRIGGER IF EXISTS trg_processar_fds_raw_json ON fds;
DROP FUNCTION IF EXISTS fn_trg_processar_fds_raw_json();
DROP FUNCTION IF EXISTS fn_processar_fds_raw_json(INTEGER);

DROP TRIGGER IF EXISTS trg_auditoria_usuario ON usuario;
DROP TRIGGER IF EXISTS trg_auditoria_fds ON fds;

DROP TRIGGER IF EXISTS trg_validar_estante_produto ON estante_produto;
DROP FUNCTION IF EXISTS fn_validar_estante_produto();

DROP FUNCTION IF EXISTS buscar_compatibilidade(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS buscar_incompatibilidades(INTEGER);
DROP FUNCTION IF EXISTS buscar_dados_fds(INTEGER);
DROP PROCEDURE IF EXISTS registrar_consulta(INTEGER, INTEGER, INTEGER, TEXT);
DROP PROCEDURE IF EXISTS cadastrar_produto_completo(
    VARCHAR, INTEGER, TEXT, VARCHAR, VARCHAR,
    INTEGER, VARCHAR, DATE, TEXT, JSONB
);

DROP FUNCTION IF EXISTS fn_atualizar_ultima_sessao();
DROP TRIGGER IF EXISTS TRIGGER trg_atualizar_ultima_sessao ON usuario_sessao_evento();



CREATE OR REPLACE FUNCTION buscar_compatibilidade(
    p_id_produto    INTEGER,
    p_id_superficie INTEGER
)
RETURNS NUMERIC(5,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nivel NUMERIC(5,2);
BEGIN
    SELECT ps.nivel_compativel
      INTO v_nivel
      FROM produto_superficie ps
     WHERE ps.id_produto = p_id_produto
       AND ps.id_superficie = p_id_superficie;

    RETURN v_nivel;
END;
$$;


CREATE OR REPLACE FUNCTION buscar_incompatibilidades(
    p_id_produto INTEGER
)
RETURNS TABLE (
    substancia_reagente VARCHAR(255),
    descricao_risco     TEXT,
    severidade          VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT fi.substancia_reagente,
           fi.descricao_risco,
           fi.severidade
      FROM fds f
      JOIN fds_incompatibilidade fi ON fi.id_fds = f.id
     WHERE f.id_produto = p_id_produto;
END;
$$;


CREATE OR REPLACE FUNCTION buscar_dados_fds(
    p_id_produto INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
DECLARE
    v_json JSONB;
BEGIN
    SELECT f.raw_json
      INTO v_json
      FROM fds f
     WHERE f.id_produto = p_id_produto
     ORDER BY f.data_atualizacao DESC NULLS LAST, f.id DESC
     LIMIT 1;

    RETURN v_json;
END;
$$;


CREATE OR REPLACE PROCEDURE registrar_consulta(
    p_id_usuario    INTEGER,
    p_id_produto    INTEGER,
    p_id_superficie INTEGER DEFAULT NULL,
    p_dosagem       TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nivel NUMERIC(5,2);
    v_resultado VARCHAR(50);
BEGIN
    IF p_id_superficie IS NULL THEN
        v_resultado := 'nao_avaliado';
    ELSE
        v_nivel := buscar_compatibilidade(p_id_produto, p_id_superficie);

        v_resultado := CASE
            WHEN v_nivel IS NULL THEN 'nao_avaliado'
            WHEN v_nivel >= 0.70 THEN 'compativel'
            WHEN v_nivel >= 0.40 THEN 'atencao'
            ELSE 'incompativel'
        END;
    END IF;

    INSERT INTO historico_recomendacao (
        id_produto,
        id_usuario,
        id_superficie,
        resultado,
        dosagem_sugerida
    ) VALUES (
        p_id_produto,
        p_id_usuario,
        p_id_superficie,
        v_resultado,
        p_dosagem
    );
END;
$$;



CREATE OR REPLACE PROCEDURE cadastrar_produto_completo(
    p_nome             VARCHAR,
    p_id_marca         INTEGER,
    p_descricao        TEXT,
    p_tipo_produto     VARCHAR,
    p_cod_barras       VARCHAR,
    p_id_empresa       INTEGER,
    p_versao_fds       VARCHAR DEFAULT NULL,
    p_data_atualizacao DATE    DEFAULT NULL,
    p_fonte_url        TEXT    DEFAULT NULL,
    p_raw_json         JSONB   DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_produto INTEGER;
BEGIN
    INSERT INTO produto (nome, id_marca, descricao, tipo_produto, cod_barras)
    VALUES (p_nome, p_id_marca, p_descricao, p_tipo_produto, p_cod_barras)
    RETURNING id INTO v_id_produto;

    INSERT INTO empresa_produto (id_empresa, id_produto, ativo, data_cadastro)
    VALUES (p_id_empresa, v_id_produto, TRUE, CURRENT_TIMESTAMP);

    INSERT INTO fds (id_produto, versao, data_atualizacao, fonte_url, raw_json)
    VALUES (v_id_produto, p_versao_fds, p_data_atualizacao, p_fonte_url, p_raw_json);
END;
$$;



CREATE OR REPLACE FUNCTION fn_processar_fds_raw_json(
    p_id_fds INTEGER
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_raw JSONB;
BEGIN
    SELECT f.raw_json
      INTO v_raw
      FROM fds f
     WHERE f.id = p_id_fds;

    IF v_raw IS NULL THEN
        RAISE EXCEPTION 'FDS % sem raw_json.', p_id_fds;
    END IF;

    DELETE FROM fds_composto          WHERE id_fds = p_id_fds;
    DELETE FROM fds_incompatibilidade WHERE id_fds = p_id_fds;
    DELETE FROM fds_descarte          WHERE id_fds = p_id_fds;

    INSERT INTO fds_composto (
        id_fds,
        nome_composto,
        cas_number,
        concentracao_min,
        concentracao_max
    )
    SELECT
        p_id_fds,
        COALESCE(c->>'nome_composto', c->>'nome', c->>'substancia') AS nome_composto,
        COALESCE(c->>'cas_number', c->>'cas', c->>'numero_cas')      AS cas_number,
        NULLIF(COALESCE(c->>'concentracao_min', c->>'min', c->>'conc_min'), '')::NUMERIC(5,2),
        NULLIF(COALESCE(c->>'concentracao_max', c->>'max', c->>'conc_max'), '')::NUMERIC(5,2)
    FROM jsonb_array_elements(
        COALESCE(
            v_raw #> '{secoes,03_composicao,ingredientes}',
            v_raw #> '{secoes,composicao,ingredientes}',
            v_raw #> '{compostos}',
            '[]'::jsonb
        )
    ) c;

    INSERT INTO fds_incompatibilidade (
        id_fds,
        substancia_reagente,
        descricao_risco,
        severidade
    )
    SELECT
        p_id_fds,
        COALESCE(i->>'substancia_reagente', i->>'substancia', i->>'agente') AS substancia_reagente,
        COALESCE(i->>'descricao_risco', i->>'risco', i->>'descricao')         AS descricao_risco,
        COALESCE(i->>'severidade', 'media')::VARCHAR(20)                      AS severidade
    FROM jsonb_array_elements(
        COALESCE(
            v_raw #> '{secoes,10_estabilidade_reatividade,incompatibilidades}',
            v_raw #> '{secoes,incompatibilidades}',
            v_raw #> '{incompatibilidades}',
            '[]'::jsonb
        )
    ) i;

    -- Seção 12: descarte
    INSERT INTO fds_descarte (
        id_fds,
        instrucao_descarte,
        tipo_residuo
    )
    SELECT
        p_id_fds,
        COALESCE(d->>'instrucao_descarte', d->>'instrucao', d->>'orientacao') AS instrucao_descarte,
        COALESCE(d->>'tipo_residuo', 'comum')::VARCHAR(50)                     AS tipo_residuo
    FROM jsonb_array_elements(
        COALESCE(
            v_raw #> '{secoes,12_descarte_transporte,descarte}',
            v_raw #> '{secoes,descarte,itens}',
            v_raw #> '{descarte}',
            '[]'::jsonb
        )
    ) d;
END;
$$;


CREATE OR REPLACE FUNCTION fn_trg_processar_fds_raw_json()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.raw_json IS NOT NULL THEN
        PERFORM fn_processar_fds_raw_json(NEW.id);
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_processar_fds_raw_json
AFTER INSERT OR UPDATE OF raw_json ON fds
FOR EACH ROW
EXECUTE FUNCTION fn_trg_processar_fds_raw_json();


CREATE OR REPLACE FUNCTION fn_validar_estante_produto()
RETURNS TRIGGER AS $$
DECLARE
    v_id_usuario_estante INTEGER;
BEGIN
    SELECT e.id_usuario
      INTO v_id_usuario_estante
      FROM estante e
     WHERE e.id = NEW.id_estante;

    IF v_id_usuario_estante IS NULL THEN
        RAISE EXCEPTION 'Estante % não encontrada.', NEW.id_estante;
    END IF;

    IF NEW.id_usuario IS NULL THEN
        RAISE EXCEPTION 'id_usuario é obrigatório em estante_produto.';
    END IF;

    IF NEW.id_usuario <> v_id_usuario_estante THEN
        RAISE EXCEPTION
            'Usuário % não é dono da estante % (dono: %).',
            NEW.id_usuario, NEW.id_estante, v_id_usuario_estante;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_estante_produto
BEFORE INSERT OR UPDATE ON estante_produto
FOR EACH ROW
EXECUTE FUNCTION fn_validar_estante_produto();

CREATE OR REPLACE FUNCTION fn_atualizar_ultima_sessao()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE usuario
        SET ultima_sessao = NEW.ocorreu_em
        WHERE id = NEW.id_usuario
            AND (ultima_sessao IS NULL OR ultima_sessao < NEW.ocorreu_em);
            RETURN NEW;
        END;
        $$;

CREATE TRIGGER trg_atualizar_ultima_sessao
AFTER INSERT ON usuario_sessao_evento
FOR EACH ROW
EXECUTE FUNCTION fn_atualizar_ultima_sessao();