import csv

from src.database.execute_sql import executar_scripts
from src.database.utils.staging.loader import rodar_pipeline
from src.database.utils.data_generators.generate_estante import gerar_estante, buscar_usuarios_existentes
from src.database.connection import get_connection


def main():
    executar_scripts([
        "src/database/sql/ddl/tables/create_tables.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_usuario_empresa.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_ponto_parceiro.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_localizacao_usuario.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_marca.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_superficie.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_classe_quimica.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_substancia.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_estante.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_substancia_classe_quimica.sql",
        "src/database/sql/data_load/staging/ddl_staging/stg_substancia_sinonimo.sql",

        # "src/database/sql/routines/functions/fn_atualizar_ultima_sessao.sql",
        # "src/database/sql/routines/functions/fn_buscar_compatibilidade.sql",
        # "src/database/sql/routines/functions/fn_buscar_dados_fds.sql",
        # "src/database/sql/routines/functions/fn_buscar_incompatibilidades_existentes.sql",
        # "src/database/sql/routines/functions/fn_match.sql",
        # "src/database/sql/routines/functions/fn_processar_fds_raw_json.sql",
        # "src/database/sql/routines/functions/fn_validar_estante_produto.sql",
        # "src/database/sql/routines/functions/fn_trg_processar_fds_raw_json.sql",

        # "src/database/sql/routines/procedures/pd_cadastrar_produto_completo.sql",
        # "src/database/sql/routines/procedures/pd_registrar_consulta.sql",

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
    rodar_pipeline("marca", "src/database/sql/data_load/mocks/marca.csv")
    rodar_pipeline("superficie", "src/database/sql/data_load/mocks/superficie.csv")
    rodar_pipeline("classe_quimica", "src/database/sql/data_load/mocks/classe_quimica.csv")
    rodar_pipeline("substancia", "src/database/sql/data_load/mocks/substancia.csv")
    rodar_pipeline("substancia_classe_quimica", "src/database/sql/data_load/mocks/substancia_classe_quimica.csv")
    rodar_pipeline("substancia_sinonimo", "src/database/sql/data_load/mocks/substancia.csv")

    caminho_estante_csv = "src/database/sql/data_load/mocks/estante.csv"
    conn = get_connection()
    ids_usuario = buscar_usuarios_existentes(conn)
    conn.close()

    linhas = gerar_estante(n=200, ids_usuario=ids_usuario)
    with open(caminho_estante_csv, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=["id_usuario", "nome", "ambiente"])
            writer.writeheader()
            writer.writerows(linhas)

    rodar_pipeline("estante", caminho_estante_csv)
    
if __name__ == "__main__":
    main()
        # rodar_pipeline("usuario", "src/database/sql/data_load/mocks/usuario.csv")
        # rodar_pipeline("empresa", "src/database/sql/data_load/mocks/empresa.csv")
        # rodar_pipeline("ponto_parceiro", "src/database/sql/data_load/mocks/ponto_parceiro.csv")
        # rodar_pipeline("localizacao_usuario", "src/database/sql/data_load/mocks/localizacao_usuario.csv")
        # rodar_pipeline("marca", "src/database/sql/data_load/mocks/marca.csv")
        # rodar_pipeline("superficie", "src/database/sql/data_load/mocks/superficie.csv")
        # rodar_pipeline("classe_quimica", "src/database/sql/data_load/mocks/classe_quimica.csv")
        # rodar_pipeline("substancia", "src/database/sql/data_load/mocks/substancia.csv")
        # rodar_pipeline("estante", "src/database/sql/data_load/mocks/estante.csv")
    
