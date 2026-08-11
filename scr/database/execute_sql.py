from database.connection import get_connection

def executar_scripts(arquivos):
    conn = get_connection()
    cursor = conn.cursor()
    print("Conexão estabelecida com o banco de dados")

    try:
        for arquivo in arquivos:
            print(f"Executando {arquivo}")

            with open(arquivo, "r", encoding="utf-8") as f:
                cursor.execute(f.read())

            print(f"Concluído: {arquivo}")

        conn.commit()

    except Exception as e:
        conn.rollback()
        print(f"Erro ao executar os scripts: {e}")
        raise e


    finally:
        cursor.close()
        conn.close()
        print("Conexão fechada")