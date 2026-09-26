import csv

from src.database.execute_sql import executar_scripts
from src.database.utils.staging.loader import rodar_pipeline
from src.database.connection import get_connection

from src.database.utils.data_generators.generate_estante import (
    gerar_estante, buscar_usuarios_existentes,
)
from src.database.utils.data_generators.generate_localizacao_usuario import gerar_localizacao_usuario
from src.database.utils.data_generators.generate_ponto_parceiro import gerar_ponto_parceiro
from src.database.utils.data_generators.generate_substancia_classe_quimica import (
    gerar_substancia_classe_quimica, buscar_ids as buscar_ids_scq, resolver_pares_curados,
)
from src.database.utils.data_generators.generate_substancia_sinonimo import (
    gerar_substancia_sinonimo, buscar_substancias,
)
from src.database.utils.data_generators.generate_produto import (
    gerar_produto, buscar_marcas,
)
from src.database.utils.data_generators.generate_historico_recomendacao import (
    gerar_historico_recomendacao, buscar_ids as buscar_ids_hr, buscar_usuarios,
)
from src.database.utils.data_generators.generate_incompatibilidade_regra import (
    gerar_incompatibilidade_regra, buscar_ids as buscar_ids_ir,
)


def salvar_csv(caminho: str, linhas: list[dict], fieldnames: list[str]):
    with open(caminho, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(linhas)
    return caminho


def main():
    executar_scripts([
        "src/database/sql/ddl/tables/create_tables.sql",
        "src/database/sql/logs/sessao_acesso.sql",
        "src/database/sql/logs/log_auditoria.sql",
        "src/database/sql/ddl/tables/catalogo.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_usuario_empresa.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_ponto_parceiro.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_localizacao_usuario.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_marca.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_classe_quimica.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_substancia.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_estante.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_substancia_classe_quimica.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_substancia_sinonimo.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_produto.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_historico_recomendacao.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_incompatibilidade_regra.sql",

        "src/database/sql/routines/functions/fn_auditoria.sql",
        "src/database/sql/routines/functions/fn_atualizar_ultima_sessao.sql",
        "src/database/sql/routines/functions/fn_buscar_dados_fds.sql",
        "src/database/sql/routines/functions/fn_buscar_incompatibilidades_existentes.sql",
        "src/database/sql/routines/functions/fn_match.sql",
        "src/database/sql/routines/functions/fn_processar_fds_raw_json.sql",
        "src/database/sql/routines/functions/fn_validar_estante_produto.sql",
        "src/database/sql/routines/functions/fn_trg_processar_fds_raw_json.sql",
        "src/database/sql/routines/functions/fn_sincronizar_catalogo.sql",

        "src/database/sql/routines/procedures/pd_cadastrar_produto_completo.sql",
        "src/database/sql/routines/procedures/pd_registrar_consulta_match.sql",

        "src/database/sql/routines/triggers/trg_atualizar_ultima_sessao.sql",
        "src/database/sql/routines/triggers/trg_auditoria_fds.sql",
        "src/database/sql/routines/triggers/trg_auditoria_usuario.sql",
        "src/database/sql/routines/triggers/trg_processar_fds_raw_json.sql",
        "src/database/sql/routines/triggers/trg_validar_estante_produto.sql",

        "src/database/sql/ddl/constraints/foreign_keys.sql",

        "src/database/sql/indexes/idx_fds_id_produto.sql",
        "src/database/sql/indexes/idx_fds_produto_ativo.sql",
        "src/database/sql/indexes/idx_fds_composto_id_fds.sql",
        "src/database/sql/indexes/idx_fds_composto_id_substancia.sql",
        "src/database/sql/indexes/idx_fds_incompat_id_fds.sql",
        "src/database/sql/indexes/idx_fds_descarte_id_fds.sql",
        "src/database/sql/indexes/idx_fds_primeiro_socorro_id_fds.sql",
        "src/database/sql/indexes/idx_substancia_sinonimo_id_substancia.sql",
        "src/database/sql/indexes/idx_produto_id_marca.sql",
        "src/database/sql/indexes/idx_sessao_acesso_id_usuario.sql",
        "src/database/sql/indexes/idx_sessao_acesso_ocorreu_em.sql",
        "src/database/sql/indexes/idx_log_auditoria_tabela_data.sql",

        "src/database/sql/ddl/comments/comments_tabelas.sql",
    ])

    rodar_pipeline("usuario", "src/database/sql/data_load/mocks/usuario.csv")
    rodar_pipeline("empresa", "src/database/sql/data_load/mocks/empresa.csv")

    # Os ids de usuario (gen_random_uuid) e de empresa (serial) mudam a cada setup,
    # então os CSVs que apontam para eles são gerados agora, com os ids recém-migrados.
    conn = get_connection()
    ids_usuario = buscar_usuarios_existentes(conn)
    with conn.cursor() as cur:
        cur.execute("SELECT id FROM empresa")
        ids_empresa = [linha[0] for linha in cur.fetchall()]
    conn.close()

    csv_ponto = salvar_csv(
        "src/database/sql/data_load/mocks/ponto_parceiro.csv",
        gerar_ponto_parceiro(ids_empresa, n=200),
        ["id_empresa", "nome", "cep", "estado", "bairro", "rua", "numero", "complemento", "tipo", "ativo"],
    )
    rodar_pipeline("ponto_parceiro", csv_ponto)

    linhas_localizacao = gerar_localizacao_usuario(ids_usuario, n=500)
    csv_localizacao = salvar_csv(
        "src/database/sql/data_load/mocks/localizacao_usuario.csv",
        linhas_localizacao,
        ["id_usuario", "cep", "estado", "bairro", "rua", "numero", "complemento"],
    )
    rodar_pipeline("localizacao_usuario", csv_localizacao)

    rodar_pipeline("marca", "src/database/sql/data_load/mocks/marca.csv")
    rodar_pipeline("classe_quimica", "src/database/sql/data_load/mocks/classe_quimica.csv")
    rodar_pipeline("substancia", "src/database/sql/data_load/mocks/substancia.csv")

    linhas_estante = gerar_estante(n=200, ids_usuario=ids_usuario)
    csv_estante = salvar_csv(
        "src/database/sql/data_load/mocks/estante.csv",
        linhas_estante,
        ["id_usuario", "nome", "ambiente"],
    )
    rodar_pipeline("estante", csv_estante)


    conn = get_connection()
    ids_substancia_scq = buscar_ids_scq(conn, "substancia")
    ids_classe_scq = buscar_ids_scq(conn, "classe_quimica")
    pares_curados_scq = resolver_pares_curados(conn)
    conn.close()

    linhas_scq = gerar_substancia_classe_quimica(
        n=60, ids_substancia=ids_substancia_scq, ids_classe=ids_classe_scq, pares_curados=pares_curados_scq
    )
    csv_scq = salvar_csv(
        "src/database/sql/data_load/mocks/substancia_classe_quimica.csv",
        linhas_scq,
        ["id_substancia", "id_classe_quimica"],
    )
    rodar_pipeline("substancia_classe_quimica", csv_scq)

    conn = get_connection()
    substancias = buscar_substancias(conn)
    conn.close()

    linhas_sinonimo = gerar_substancia_sinonimo(n=200, substancias=substancias)
    csv_sinonimo = salvar_csv(
        "src/database/sql/data_load/mocks/substancia_sinonimo.csv",
        linhas_sinonimo,
        ["id_substancia", "sinonimo"],
    )
    rodar_pipeline("substancia_sinonimo", csv_sinonimo)

    conn = get_connection()
    ids_marca = buscar_marcas(conn)
    conn.close()

    linhas_produto = gerar_produto(n=200, ids_marca=ids_marca)
    csv_produto = salvar_csv(
    "src/database/sql/data_load/mocks/produto.csv",
    linhas_produto,
    ["nome", "id_marca", "descricao", "tipo_produto", "cod_barras", "foto_url"],
    )
    rodar_pipeline("produto", csv_produto)

    conn = get_connection()
    ids_produto = buscar_ids_hr(conn, "produto")
    ids_usuario_hr = buscar_usuarios(conn)
    conn.close()

    linhas_historico = gerar_historico_recomendacao(
        n=300,
        ids_produto=ids_produto,
        ids_usuario=ids_usuario_hr,
    )
    csv_historico = salvar_csv(
        "src/database/sql/data_load/mocks/historico_recomendacao.csv",
        linhas_historico,
        ["id_produto", "id_usuario", "resultado", "dosagem_sugerida"],
    )
    rodar_pipeline("historico_recomendacao", csv_historico)

    conn = get_connection()
    ids_substancia_ir = buscar_ids_ir(conn, "substancia")
    ids_classe_ir = buscar_ids_ir(conn, "classe_quimica")
    conn.close()

    linhas_incompatibilidade = gerar_incompatibilidade_regra(
        n=150, ids_substancia=ids_substancia_ir, ids_classe=ids_classe_ir
    )
    csv_incompatibilidade = salvar_csv(
        "src/database/sql/data_load/mocks/incompatibilidade_regra.csv",
        linhas_incompatibilidade,
        [
            "id_substancia_a", "id_classe_a",
            "id_substancia_b", "id_classe_b",
            "severidade", "descricao_risco", "fonte", "ativo",
        ],
    )
    rodar_pipeline("incompatibilidade_regra", csv_incompatibilidade)

    executar_scripts([
        "src/database/sql/data_mart/dim/dim_tempo.sql",
        "src/database/sql/data_mart/dim/dim_produto.sql",
        "src/database/sql/data_mart/dim/dim_usuario.sql",
        "src/database/sql/data_mart/dim/dim_substancia.sql",
        "src/database/sql/data_mart/dim/dim_localizacao.sql",
        "src/database/sql/data_mart/facts/vw_fato_historico_recomendacao.sql",
        "src/database/sql/data_mart/facts/vw_fato_historico_match.sql",
        "src/database/sql/data_mart/facts/vw_fato_auditoria.sql",
        "src/database/sql/data_mart/facts/vw_dau.sql",
        "src/database/sql/data_mart/facts/vw_fato_cobertura_incompatibilidade.sql",
        "src/database/sql/data_mart/facts/vw_fato_sessao_acesso.sql",
        "src/database/sql/data_mart/facts/vw_fato_adocao_estante.sql",
        "src/database/sql/data_mart/facts/vw_qualidade_resolucao_fds.sql",
        "src/database/sql/data_mart/facts/vw_catalogo_dados.sql",

        "src/database/sql/data_mart/comments/comments_views.sql",
        "src/database/sql/data_load/seeds/executar_sincronizacao_catalogo.sql",
        "src/database/sql/data_load/seeds/seed_catalogo_classificacao.sql",
    ])


if __name__ == "__main__":
    main()