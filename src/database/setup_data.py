from database.execute_sql import executar_scripts

executar_scripts([
    "database/sql/ddl/tables/create_tables.sql",
    
    "database/sql/programmability/functions/fn_atualizar_ultima_sessao.sql",
    "database/sql/programmability/functions/fn_buscar_compatibilidade.sql",
    "database/sql/programmability/functions/fn_buscar_dados_fds.sql",
    "database/sql/programmability/functions/fn_buscar_incompatibilidades_existentes.sql",
    "database/sql/programmability/functions/fn_match.sql",
    "database/sql/programmability/functions/fn_processar_fds_raw_json.sql",
    "database/sql/programmability/functions/fn_validar_estante_produto.sql",
    "database/sql/programmability/functions/fn_trg_processar_fds_raw_json.sql",
    
    "database/sql/programmability/procedures/pd_cadastrar_produto_completo.sql",
    "database/sql/programmability/procedures/pd_registrar_consulta.sql",
    
    "database/sql/programmability/triggers/trg_atualizar_ultima_sessao.sql",
    "database/sql/programmability/triggers/trg_auditoria_fds.sql",
    "database/sql/programmability/triggers/trg_auditoria_usuario.sql",
    "database/sql/programmability/triggers/trg_processar_fds_raw_json.sql",

    "database/sql/ddl/constraints/foreign_keys.sql"
])