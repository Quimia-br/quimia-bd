from database.execute_sql import executar_scripts

executar_scripts([
    "scripts/tables/create_tables.sql",
    "scripts/constraints/foreign_keys.sql"
    "scripts/routines/stored_routines.sql"
])