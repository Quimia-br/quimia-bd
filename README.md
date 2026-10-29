# quimia-bd

Banco de dados do Quimia (PostgreSQL): modelagem, rotinas, carga de dados, RPA de integração com o banco legado, data mart e catálogo de dados. **Catálogo de dados online: https://quimia-br.github.io/quimia-bd/**

O Quimia cadastra produtos de limpeza com suas FDS (fichas de dados de segurança) e detecta combinações perigosas entre eles.

## Arquitetura

```
 banco legado (PostgreSQL) ──RPA──┐
                                  ▼
 mocks (CSV / Faker) ───────► staging stg_* ──validação──► tabelas finais ──► views do Data Mart (dim_*, vw_*)
                                                          (PostgreSQL / Aiven)        │
                                                                  │                   └── JDBC ──► Databricks
                                                                  └── auditoria, log_rpa_execucao, catálogo de dados
```

- **Banco de entrega:** PostgreSQL hospedado na Aiven (versão 18.6, SSL obrigatório).
- **Staging comum e não persistente:** toda carga passa por uma `stg_*` (COPY → validação → migração das linhas aprovadas).

## Requisitos e configuração

Validado com **Python 3.14.2**, em venv limpo. O gerador do catálogo roda só com a biblioteca padrão (o CI usa Python 3.12).

```bash
python -m venv .venv
.venv\Scripts\activate          # Linux/macOS: source .venv/bin/activate
pip install -r requirements.txt
copy .env.example .env          # Linux/macOS: cp .env.example .env  (depois preencha)
```

O `.env` é ignorado pelo git. As variáveis estão descritas em [.env.example](.env.example). `DB_*` e `DB_URL` apontam para o mesmo banco do Quimia (formatos diferentes: psycopg2 e SQLAlchemy); `RPA_DB_URL` aponta para o banco legado.

## Modelagem

O `setup_data` cria **29 tabelas** + 14 de staging (`stg_*`), com **PK em todas as tabelas de negócio** e FKs em `src/database/sql/ddl/constraints/foreign_keys.sql`.

| Grupo | Tabelas |
|---|---|
| Catálogo químico | `marca`, `produto`, `substancia`, `substancia_sinonimo`, `classe_quimica`, `substancia_classe_quimica`, `incompatibilidade_regra`, `sinonimo_pendente` |
| FDS | `fds`, `fds_composto`, `fds_incompatibilidade`, `fds_primeiro_socorro`, `fds_descarte` |
| Usuários e uso | `usuario`, `localizacao_usuario`, `estante`, `comodo`, `estante_produto`, `historico_recomendacao`, `historico_match`, `sessao_acesso` |
| Parceiros | `empresa`, `empresa_produto`, `ponto_parceiro`, `ponto_salvo` |
| Operação e governança | `log_auditoria`, `log_rpa_execucao`, `catalogo_tabela`, `catalogo_coluna` |

O banco da Aiven tem ainda 4 tabelas do **back-end** que o `setup_data` não cria: `auditoria_autenticacao`, `recuperacao_senha`, `refresh_token` e `flyway_schema_history`.

**Cardinalidades principais**

| Relação | Cardinalidade | Implementação |
|---|---|---|
| `marca` → `produto` | 1:N | `produto.id_marca` |
| `produto` → `fds` | 1:N | `fds.id_produto` |
| `fds` → `fds_composto`, `fds_incompatibilidade`, `fds_primeiro_socorro`, `fds_descarte` | 1:N | `id_fds` (ON DELETE CASCADE) |
| `substancia` ↔ `classe_quimica` | N:N | `substancia_classe_quimica`, `UNIQUE (id_substancia, id_classe_quimica)` |
| `substancia` → `substancia_sinonimo` | 1:N | `sinonimo_normalizado` único |
| `incompatibilidade_regra` | cada lado (A e B) referencia uma substância **ou** uma classe | `CHECK chk_regra_lado_a/b` |
| `empresa` ↔ `produto` | N:N | `empresa_produto`, `UNIQUE (id_empresa, id_produto)` |
| `empresa` → `ponto_parceiro` | 1:N | `ponto_parceiro.id_empresa` |
| `usuario` ↔ `ponto_parceiro` | N:N | `ponto_salvo`, `UNIQUE (id_usuario, id_ponto)` |
| `usuario` → `localizacao_usuario` | 1:1 | `UNIQUE (id_usuario)` |
| `usuario` → `estante` | 1:1 | `UNIQUE (id_usuario)` |
| `estante` ↔ `produto` | N:N | `estante_produto`, `UNIQUE (id_estante, id_produto)` |
| `usuario` → `comodo`, `historico_recomendacao`, `historico_match`, `sessao_acesso` | 1:N | `id_usuario` |

**Normalização.** O modelo separa os domínios em tabelas próprias (marca, classe, substância, FDS e seus filhos) e resolve os N:N por tabelas associativas, mirando a 3FN. A 3FN **não foi auditada formalmente** nesta entrega, e há exceções conhecidas:

- `estante_produto.id_usuario` repete o dono da estante (`estante.id_usuario`); a consistência é garantida pelo trigger `trg_validar_estante_produto`.
- `usuario.ultima_sessao` é derivado de `sessao_acesso` e mantido pelo trigger `trg_atualizar_ultima_sessao`.
- `historico_match` guarda uma cópia (`severidade`, `descricao_risco`) da regra aplicada, para preservar o resultado da época da consulta.
- Endereço (`estado`, `bairro`, `rua`) fica na mesma linha do `cep` em `localizacao_usuario` e `ponto_parceiro`, sem tabela de CEP.
- `fds.raw_json` guarda a FDS bruta (JSONB); os dados normalizados ficam em `fds_*`.

## Pipeline principal: `setup_data`

```bash
python -m src.setup_data
```

> **Atenção:** apaga e recria os objetos do banco apontado pelas variáveis `DB_*`. Confira o destino antes de rodar.

Fluxo real de `src/setup_data.py`:

1. **DDL:** `create_tables.sql` (DROP + CREATE, extensões `pgcrypto` e `unaccent`), tabelas de log, catálogo e staging; depois functions, procedures, triggers, FKs, índices e `COMMENT ON`.
2. **Carga** (`rodar_pipeline` em `src/database/utils/staging/loader.py`): para cada tabela, `TRUNCATE` da `stg_*` → `COPY` do CSV → `validate_*.sql` (marca cada linha como `ok` ou `rejeitado`, com `motivo_rejeicao`) → `migrate_*.sql` (move só as linhas `ok`). Os CSVs vêm de mocks fixos (`usuario`, `empresa`, `marca`, `classe_quimica`, `substancia`, `seeds/`) ou de geradores Faker em `src/database/utils/data_generators/`.
3. **Data Mart:** dimensões e fatos, comentários das views, sincronização do catálogo e seed de classificação.

Linhas rejeitadas ficam na `stg_*` com o motivo até a próxima carga daquela tabela (o `TRUNCATE` do staging roda no início de cada carga).

**Massa de dados** (banco da Aiven, snapshot do backup de 2026-10-29):

| Tabela | Linhas | Tabela | Linhas |
|---|---:|---|---:|
| `usuario` | 819 | `incompatibilidade_regra` | 89 |
| `empresa` | 39 | `estante` | 143 |
| `marca` | 92 | `localizacao_usuario` | 379 |
| `produto` | 120 | `ponto_parceiro` | 161 |
| `substancia` | 15 | `historico_recomendacao` | 217 |
| `classe_quimica` | 10 | `substancia_sinonimo` | 88 |
| `substancia_classe_quimica` | 18 | `sessao_acesso` | 44.968 |

Soma das tabelas oficiais acima: **47.158 registros** (o requisito de 500+ vale pelo total, não por tabela). Vazias na Aiven: `comodo`, `estante_produto`, `empresa_produto`, `ponto_salvo`, `historico_match`, `fds` e filhas, `log_rpa_execucao`.

## RPA (banco legado → Quimia)

```bash
python -m src.rpa.orchestrator
```

> **Estado: EM VALIDAÇÃO.** Veja a evidência abaixo antes de tratar a integração como operacional.

**Fluxo** (`src/rpa/`): `orchestrator.py` percorre a lista `PROCESSOS` (hoje só `usuario`). Para cada processo:

1. `log_execucao.iniciar` grava uma linha em **`log_rpa_execucao`** com `status = 'rodando'`.
2. `ultimo_watermark` lê o `ultimo_watermark` da última execução com `sucesso` (extração incremental; sem execução anterior, extrai tudo).
3. `extractors/extrair_usuario.py` lê `usuarios` do **banco legado** (`RPA_DB_URL`, somente `SELECT`) com `data_cadastro > watermark`, renomeia as colunas para o formato do staging e filtra por `status` do legado (`ATIVO`, `INATIVO`, `PENDENTE`, `BLOQUEADO`, `DESATIVADO`). A senha do legado **não é copiada**: cada usuário recebe uma senha temporária (hash bcrypt) e `nivel_acesso = 'usuario'`.
4. O resultado vira um CSV temporário (`src/rpa/_tmp/`, ignorado pelo git) e entra no mesmo `loader.rodar_pipeline("usuario", ...)` do `setup_data`: staging → `validate_usuario.sql` → `migrate_usuario_empresa.sql`.
5. `log_execucao.finalizar` registra `sucesso` (com `linhas_processadas` e o novo watermark = maior `cadastro`) ou `falha` (com `mensagem_erro`).

**Validação do usuário** (`validate_usuario.sql`): nome preenchido, e-mail em formato válido, sem duplicidade no lote nem já cadastrado, senha com 60 caracteres (hash bcrypt), `foto_url` http(s), `data_nasc` válida, `nivel_acesso` no domínio e `ultima_sessao` válida.

**Tratamento de falhas:** qualquer exceção é capturada, gravada em `log_rpa_execucao` (`status = 'falha'` + `mensagem_erro`) e a conexão do loader faz `rollback`, então uma exceção nunca deixa a linha em `rodando` (só um processo encerrado à força deixaria). Limitação: o processo termina com código 0 mesmo quando a execução é registrada como `falha`; consulte `log_rpa_execucao` para saber o resultado.

**Evidência do estado atual (2026-10-29):**

- O legado tem **99 linhas** em `usuarios`.
- Em **banco local descartável**, a execução completa aprovou 99 de 99 na validação, migrou as linhas e registrou `sucesso` com `linhas_processadas = 99`. Uma 2ª execução imediata registrou `sucesso` com 0 linhas ("nenhuma linha nova"), pelo watermark.
- Na **Aiven** (banco de entrega), `log_rpa_execucao` está **vazia**: o RPA ainda não foi executado lá.
- Um teste anterior da equipe relatou 100/100 registros rejeitados; esse resultado **não foi reproduzido** e a causa **não foi identificada**.

## Eventos e acesso

- **`sessao_acesso`** (`id`, `id_usuario`, `ocorreu_em`): uma linha por login. É carregada pelo mesmo fluxo de staging (`stg_sessao_acesso`), tem índices por usuário e por data, e o trigger `trg_atualizar_ultima_sessao` copia o horário mais recente para `usuario.ultima_sessao`. É a fonte do DAU.
- **`evento_app`: não existe** neste repositório. Eventos de navegação do app não são modelados; o uso é medido por `sessao_acesso`.

## Data Mart

As dimensões e os fatos são **views** sobre as tabelas finais (não materializadas), no formato **estrela**: cada fato se liga às dimensões por chave. Não há snowflake.

| Tipo | Views |
|---|---|
| Dimensões | `dim_tempo`, `dim_produto`, `dim_usuario`, `dim_substancia`, `dim_localizacao` |
| Fatos | `vw_fato_historico_recomendacao`, `vw_fato_historico_match`, `vw_fato_sessao_acesso`, `vw_fato_adocao_estante`, `vw_fato_auditoria`, `vw_cobertura_incompatibilidade`, `vw_qualidade_resolucao_fds` |
| Monitoramento e apoio | `vw_dau`, `vw_sequencia_uso`, `vw_catalogo_dados` |

- **CTE:** `vw_fato_historico_recomendacao` (CTEs `base`, `ranking_produto`, `running_total_diario`), `vw_sequencia_uso`, `fn_match_produtos` e as validações do staging (`validate_*.sql`).
- **Window functions:** `RANK() OVER` e `SUM(COUNT(*)) OVER` em `vw_fato_historico_recomendacao`; `COUNT(*) OVER (PARTITION BY ...)` em `vw_fato_sessao_acesso` e `vw_fato_historico_match`; `ROW_NUMBER() OVER` nas validações de duplicidade do staging.
- **`WITH RECURSIVE`:** `vw_sequencia_uso` calcula as sequências de dias consecutivos de uso por usuário. É uma view para análise do conjunto completo; para um único usuário, veja a reescrita em [docs/explain_analyze.md](docs/explain_analyze.md).
- `vw_fato_historico_match` e `vw_qualidade_resolucao_fds` retornam 0 linhas hoje, porque as tabelas de origem (`historico_match`, `fds*`) estão vazias.

## DAU

O DAU (usuários ativos por dia) é calculado diretamente no PostgreSQL pela view `vw_dau` ([vw_dau.sql](src/database/sql/data_mart/facts/vw_dau.sql)):

```sql
SELECT ocorreu_em::date AS data, COUNT(DISTINCT id_usuario) AS usuarios_ativos
FROM sessao_acesso
GROUP BY ocorreu_em::date;
```

Hoje cobre 360 dias. Para uma janela recente, filtre por intervalo em `sessao_acesso.ocorreu_em` (usa `idx_sessao_acesso_ocorreu_em`); filtrar pela coluna `data` da view força leitura completa (medição em [docs/explain_analyze.md](docs/explain_analyze.md)).

## Rotinas, triggers e auditoria

| Tipo | Objetos do projeto |
|---|---|
| Functions (15) | `fn_match_produtos`, `buscar_dados_fds`, `buscar_incompatibilidades`, `buscar_pontos_salvos`, `buscar_primeiros_socorros`, `fn_processar_fds_raw_json`, `fn_sincronizar_catalogo`, validadores (`fn_data_valida`, `fn_inteiro_valido`, `fn_numerico_valido`, `fn_timestamp_valido`) e funções de trigger |
| Procedures (3) | `cadastrar_produto_completo`, `guardar_produto_estante`, `sp_registrar_consulta_match` |
| Triggers (5) | auditoria em `usuario` e `fds`; `sessao_acesso` (última sessão); `estante_produto` (dono da estante); `fds` (processa o `raw_json`) |

**Auditoria:** `fn_auditoria()` grava em `log_auditoria` a tabela (`TG_TABLE_NAME`), a operação (`TG_OP`), o registro anterior (`OLD`), o novo (`NEW`) e o `CURRENT_USER`.

**Demonstração** de `CALL` e auditoria, dentro de uma transação com `ROLLBACK` (não deixa dados):

```bash
psql -d <banco> -f src/database/sql/tests/demo_call_auditoria.sql
```

## Databricks (PostgreSQL/Aiven → JDBC → Databricks)

O Databricks consome as dimensões e os fatos do Data Mart direto do PostgreSQL por JDBC. A configuração do lado Databricks (cluster, segredos) **não está neste repositório**; o padrão de leitura, com placeholders, é:

```python
df = (spark.read.format("jdbc")
      .option("url", "jdbc:postgresql://<HOST>:<PORTA>/<BANCO>?sslmode=require")
      .option("dbtable", "public.vw_dau")
      .option("user", dbutils.secrets.get("<escopo>", "<chave-usuario>"))
      .option("password", dbutils.secrets.get("<escopo>", "<chave-senha>"))
      .option("driver", "org.postgresql.Driver")
      .load())
```

Usuário e senha ficam em segredos do Databricks, nunca no código nem no repositório. A Aiven exige SSL, por isso `sslmode=require`.

## Backup e recovery

`ops/backup.py`, `ops/verify_backup.py` e `ops/restore.py` (`pg_dump -Fc` / `pg_restore`, restore sempre em destino explícito, nunca na Aiven). Evidência do teste real, versões e contagens antes/depois em [docs/backup_recovery.md](docs/backup_recovery.md). Checagem rápida do banco apontado pelo `.env`: `python ops/check_db.py`.

## Performance

Planos `EXPLAIN (ANALYZE, BUFFERS)` reais de 4 consultas (`fn_match_produtos`, DAU, `vw_fato_historico_recomendacao`, busca de produto), com análise e comparação antes/depois de índices, em [docs/explain_analyze.md](docs/explain_analyze.md).

## Governança de dados

- **Catálogo técnico no banco:** `catalogo_tabela` (nome, tipo de objeto, domínio, descrição, regra de negócio, **nível de acesso** `publico` / `interno` / `restrito`, responsável) e `catalogo_coluna` (tipo, obrigatoriedade, PK, referência, descrição, regra de negócio, `dado_pessoal_lgpd`). São preenchidas por `fn_sincronizar_catalogo()`, que lê o catálogo do PostgreSQL (colunas, PK, FK) e os `COMMENT ON`; nível de acesso, domínio e marcação LGPD vêm do seed de classificação. A view `vw_catalogo_dados` consulta tudo. No banco da Aiven: 46 objetos catalogados (26 internos, 11 públicos, 6 restritos, 3 sem classificação) e 296 colunas, 17 delas marcadas como dado pessoal.
- **Site do catálogo:** o catálogo de dados está publicado no GitHub Pages do repositório, em **https://quimia-br.github.io/quimia-bd/** (o mesmo link do campo *About* do repositório). O workflow `.github/workflows/catalog.yml` regenera e publica o site a cada push na `main` que altere `src/database/sql/**` ou `src/catalog_site/**`. Para abrir localmente, use `docs/catalog/index.html` direto no navegador (funciona via `file://`). `data.js`, `icons.js` e `diffs/` são gerados; não edite à mão, rode `python -m src.catalog_site.generate_catalog`.
- **Integridade:** PK em todas as tabelas de negócio, FKs com `ON DELETE` explícito, `UNIQUE` e `CHECK` de domínio, e validação em staging antes de qualquer migração.
- **Segurança:** conexão com `sslmode=require`; senhas em bcrypt; `.env` fora do git (`.env.example` só com placeholders); auditoria por trigger; backup com restore testado.

## Estrutura

```
src/
├── setup_data.py            # orquestra a criação e a carga do banco
├── catalog_site/            # gerador do site do catálogo (parser SQL, git, plano de execução)
├── rpa/                     # RPA legado → Quimia (orchestrator, extractors, log_execucao)
└── database/
    ├── connection.py
    ├── utils/               # geradores de dados sintéticos e loader do staging
    └── sql/
        ├── ddl/             # tabelas, constraints e COMMENT ON
        ├── routines/        # functions, procedures e triggers
        ├── indexes/
        ├── logs/            # sessao_acesso, log_auditoria e log_rpa_execucao
        ├── data_load/       # mocks (CSV), staging, validação, migração e seeds
        ├── data_mart/       # dimensões, fatos e views
        └── tests/           # demonstração de CALL e auditoria
ops/                         # backup, verify_backup, restore e check_db
docs/
├── backup_recovery.md
├── explain_analyze.md
└── catalog/                 # catálogo de dados (site estático)
```
