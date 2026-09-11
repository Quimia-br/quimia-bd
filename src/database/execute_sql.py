from src.database.connection import get_connection

def executar_scripts(arquivos):
    conn = get_connection()
    cursor = conn.cursor()
    print("Conexão estabelecida com o banco de dados.")

    try:
        for arquivo in arquivos:
            print(f"Executando: {arquivo}")

            with open(arquivo, "r", encoding="utf-8") as f:
                script_conteudo = f.read().strip()
                
                if not script_conteudo:
                    print(f"⚠️ Arquivo vazio ignorado: {arquivo}")
                    continue
                
                cursor.execute(script_conteudo)

            print(f"Concluído: {arquivo}")

        conn.commit()
        print(" Todas as alterações foram salvas com sucesso (COMMIT).")

    except Exception as e:
        conn.rollback()
        print(f"ERRO ao executar os scripts. Alterações desfeitas (ROLLBACK).")
        print(f"Detalhe do erro: {e}")
        raise e

    finally:
        cursor.close()
        conn.close()
        print("Conexão fechada com o banco de dados.")
