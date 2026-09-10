from database.execute_sql import executar_scripts

executar_scripts([
    "scripts/tables/create_tables.sql",
    "scripts/constraints/foreign_keys.sql",
    "scripts/routines/functions/fn_atualizar_ultima_sessao.sql",
    "scripts/routines/functions/fn_buscar_compatibilidade.sql",
    "scripts/routines/functions/fn_buscar_dados_fds.sql",
    "scripts/routines/functions/fn_buscar_incompatibilidades_existentes.sql",
    "scripts/routines/functions/fn_match.sql",
    "scripts/routines/functions/fn_processar_fds_raw_json.sql",
    "scripts/routines/functions/fn_validar_estante_produto.sql",
    "scripts/routines/functions/fn_trg_processar_fds_raw_json.sql",
    "scripts/routines/procedures/pd_cadastrar_produto_completo.sql",
    "scripts/routines/procedures/pd_registrar_consulta.sql",
    "scripts/routines/triggers/trg_atualizar_ultima_sessao.sql",
    "scripts/routines/triggers/trg_auditoria_fds.sql",
    "scripts/routines/triggers/trg_auditoria_usuario.sql",
    "scripts/routines/triggers/trg_processar_fds_raw_json.sql"
])