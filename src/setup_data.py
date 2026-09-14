from src.database.execute_sql import executar_scripts
from src.database.utils.staging.loader import rodar_pipeline


def main():
    executar_scripts([
        "src/database/sql/ddl/tables/create_tables.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_usuario_empresa.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_ponto_parceiro.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_localizacao_usuario.sql",

        "src/database/sql/routines/functions/fn_atualizar_ultima_sessao.sql",
        "src/database/sql/routines/functions/fn_buscar_compatibilidade.sql",
        "src/database/sql/routines/functions/fn_buscar_dados_fds.sql",
        "src/database/sql/routines/functions/fn_buscar_incompatibilidades_existentes.sql",
        "src/database/sql/routines/functions/fn_match.sql",
        "src/database/sql/routines/functions/fn_processar_fds_raw_json.sql",
        "src/database/sql/routines/functions/fn_validar_estante_produto.sql",
        "src/database/sql/routines/functions/fn_trg_processar_fds_raw_json.sql",

        "src/database/sql/routines/procedures/pd_cadastrar_produto_completo.sql",
        "src/database/sql/routines/procedures/pd_registrar_consulta.sql",

        # "src/database/sql/routines/triggers/trg_atualizar_ultima_sessao.sql",
        # "src/database/sql/routines/triggers/trg_auditoria_fds.sql",
        # "src/database/sql/routines/triggers/trg_auditoria_usuario.sql",
        # "src/database/sql/routines/triggers/trg_processar_fds_raw_json.sql",

        "src/database/sql/ddl/constraints/foreign_keys.sql"
    ])
    
    rodar_pipeline("usuario", "src/database/sql/data_load/mocks/usuario.csv")
    rodar_pipeline("empresa", "src/database/sql/data_load/mocks/empresa.csv")
    rodar_pipeline("ponto_parceiro", "src/database/sql/data_load/mocks/ponto_parceiro.csv")
    rodar_pipeline("localizacao_usuario", "src/database/sql/data_load/mocks/localizacao_usuario.csv")
    
if __name__ == "__main__":
    main()