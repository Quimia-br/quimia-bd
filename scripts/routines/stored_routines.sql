DROP TRIGGER IF EXISTS trg_validar_estante_produto ON estante_produto;
DROP FUNCTION IF EXISTS fn_validar_estante_produto();
DROP FUNCTION IF EXISTS buscar_compatibilidade(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS buscar_incompatibilidades(INTEGER);
DROP FUNCTION IF EXISTS buscar_dados_fds(INTEGER);
DROP PROCEDURE IF EXISTS registrar_consulta(INTEGER, INTEGER, INTEGER, TEXT, INTEGER);
DROP PROCEDURE IF EXISTS cadastrar_produto_completo(
    VARCHAR, INTEGER, VARCHAR, VARCHAR, VARCHAR,
    INTEGER, VARCHAR, TEXT, JSONB
);

CREATE OR REPLACE FUNCTION buscar_compatibilidade(
    p_id_produto    INTEGER,
    p_id_superficie INTEGER
)
RETURNS NUMERIC(5,2) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION buscar_incompatibilidades(
    p_id_produto INTEGER
)
RETURNS TABLE (
    substancia_reagente VARCHAR(255),
    descricao_risco     TEXT,
    severidade          VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT fi.substancia_reagente,
           fi.descricao_risco,
           fi.severidade
      FROM fds f
      JOIN fds_incompatibilidade fi ON fi.id_fds = f.id
     WHERE f.id_produto = p_id_produto;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION buscar_dados_fds(
    p_id_produto INTEGER
)
RETURNS JSONB AS $$
DECLARE
    v_json JSONB;
BEGIN
    SELECT f.raw_json
      INTO v_json
      FROM fds f
     WHERE f.id_produto = p_id_produto
     ORDER BY f.id DESC
     LIMIT 1;

    RETURN v_json;
END;
$$ LANGUAGE plpgsql;


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

CREATE OR REPLACE PROCEDURE registrar_consulta(
    p_id_usuario         INTEGER,
    p_id_produto         INTEGER,
    p_id_superficie      INTEGER DEFAULT NULL,
    p_dosagem            TEXT    DEFAULT NULL,
    p_id_usuario_produto INTEGER DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_nivel NUMERIC(5,2);
    v_resultado VARCHAR(255);
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
        id_usuario_produto,
        id_superficie,
        resultado,
        dosagem_sugerida
    ) VALUES (
        p_id_produto,
        p_id_usuario,
        p_id_usuario_produto,
        p_id_superficie,
        v_resultado,
        p_dosagem
    );
END;
$$;

CREATE OR REPLACE PROCEDURE cadastrar_produto_completo(
    p_nome         VARCHAR,
    p_id_marca     INTEGER,
    p_descricao    VARCHAR,
    p_tipo_produto VARCHAR,
    p_cod_barras   VARCHAR,
    p_id_empresa   INTEGER,
    p_cas_numero   VARCHAR DEFAULT NULL,
    p_fonte_url    TEXT    DEFAULT NULL,
    p_raw_json     JSONB   DEFAULT NULL
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

    INSERT INTO fds (id_produto, cas_numero, fonte_url, raw_json)
    VALUES (v_id_produto, p_cas_numero, p_fonte_url, p_raw_json);
END;
$$;