# Backup e Recovery — Quimia-BD

Evidência do teste real executado em 2026-10-29.

## Ambiente

| Item | Valor |
|---|---|
| Origem | PostgreSQL **18.6** na Aiven, database `quimiadb` |
| SSL | `ssl = on`, sessão TLSv1.3, `sslmode=require` |
| `pg_dump` / `pg_restore` | **18.6** (imagem Docker `postgres:18`; não há binários nativos no Windows) |
| Destino do restore | container `quimia-pg-local` (PostgreSQL **16.15**), `localhost:5433`, database `quimia_restore_test` |

O cliente 18.6 é obrigatório: `pg_dump` não exporta servidor de major mais nova, e o
`pg_restore` 16 não lê o formato de arquivo gerado pelo 18.

## Scripts

```bash
python ops/backup.py                     # pg_dump -Fc do banco do .env -> backups/<db>_<timestamp>.dump
python ops/verify_backup.py <arquivo>    # existe, tamanho > 0, assinatura PGDMP, pg_restore --list
python ops/restore.py <arquivo> --host localhost --port 5433 \
    --dbname quimia_restore_test --user postgres          # senha em RESTORE_PGPASSWORD
```

- Sem senha no código: origem lida de `DB_HOST/DB_PORT/DB_NAME/DB_USER/DB_PASSWORD` (`.env`), destino de `RESTORE_PGPASSWORD`.
- `backup.py` nunca sobrescreve (abre o arquivo em modo exclusivo) e apaga o arquivo parcial em caso de falha.
- `restore.py` exige destino explícito e recusa o host do `.env` ou qualquer host `aivencloud`; `--clean` só com `--yes`.
- Sem `pg_dump`/`pg_restore` no PATH, os scripts usam `docker run --rm postgres:18` (imagem configurável por `PG_TOOLS_IMAGE`).
- Exit code do `pg_dump`/`pg_restore` é propagado.
- `backups/` e `*.dump` estão no `.gitignore`.

## Resultado

| Etapa | Resultado |
|---|---|
| Dump | `backups/quimiadb_20261029_162535.dump`, 4.363.075 bytes |
| Verificação | assinatura `PGDMP` ok, `pg_restore --list` com 827 entradas |
| Restore | 48 tabelas, 18 rotinas do projeto (15 functions + 3 procedures) mais 40 de extensões, 14 views, 5 triggers, 83 índices, 3 extensões |
| Erros no restore | 1 ignorado: `SET transaction_timeout = 0` (parâmetro existe só a partir do PG 17; não afeta schema nem dados). Exit code do `pg_restore` = 1 por causa dele |

### Contagens antes/depois

`COUNT(*)` exato em **todas** as 48 tabelas; nenhuma divergência. Total: **114.117** linhas na origem e no restore.

| Tabela | Origem | Restore local |
|---|---:|---:|
| usuario | 819 | 819 |
| empresa | 39 | 39 |
| produto | 120 | 120 |
| estante | 143 | 143 |
| localizacao_usuario | 379 | 379 |
| ponto_parceiro | 161 | 161 |
| historico_recomendacao | 217 | 217 |
| sessao_acesso | 44.968 | 44.968 |
| log_auditoria | 17.649 | 17.649 |
| catalogo_coluna | 296 | 296 |

## Limitação

O servidor local é 16.15 e a origem 18.6. O único efeito observado foi o erro ignorado acima.
Para eliminar a diferença, o servidor local pode ser recriado com a imagem `postgres:18`.
