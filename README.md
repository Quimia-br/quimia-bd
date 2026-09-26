# quimia-bd

Banco de dados do Quimia (PostgreSQL): modelagem, rotinas, carga de dados sintéticos, data mart e catálogo de dados.

## Requisitos

- Python 3.12+
- Acesso a um PostgreSQL
- Dependências: `pip install psycopg2-binary python-dotenv faker bcrypt`

## Configuração

Crie um arquivo `.env` na raiz (ele é ignorado pelo git) com as chaves:

```
DB_HOST=
DB_PORT=5432
DB_NAME=
DB_USER=
DB_PASSWORD=
```

## Uso

```bash
# Recria o banco do zero: tabelas, rotinas, índices, carga (staging → validação → migração),
# data mart e sincronização do catálogo
python -m src.setup_data

# Regenera o site do catálogo de dados a partir dos arquivos .sql (não conecta no banco)
python -m src.catalog_site.generate_catalog
```

> `setup_data` apaga e recria os objetos a cada execução.

## Estrutura

```
src/
├── setup_data.py            # orquestra a criação e a carga do banco
├── catalog_site/            # gerador do site do catálogo (parser SQL, git, plano de execução)
└── database/
    ├── connection.py
    ├── utils/               # geradores de dados sintéticos e loader do staging
    └── sql/
        ├── ddl/             # tabelas, constraints e COMMENT ON
        ├── routines/        # functions, procedures e triggers
        ├── indexes/
        ├── logs/            # sessao_acesso e log_auditoria
        ├── data_load/       # mocks (CSV), staging, validação, migração e seeds
        └── data_mart/       # dimensões, fatos e views
docs/
└── catalog/                 # catálogo de dados (site estático)
```

## Catálogo de dados

- **No banco:** as tabelas `catalogo_tabela` e `catalogo_coluna` são preenchidas por `fn_sincronizar_catalogo()` e consultadas pela view `vw_catalogo_dados`.
- **Site:** abra `docs/catalog/index.html` direto no navegador (funciona via `file://`, sem servidor). `data.js`, `icons.js` e `diffs/` são gerados, então não edite esses arquivos à mão; rode o gerador de novo.
