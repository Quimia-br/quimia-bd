from src.database.execute_sql import executar_scripts
#from src.database.utils.data-generators.loader import rodar_pipeline


executar_scripts([
    "src/database/sql/ddl/tables/create_tables.sql",
    
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