# EXPLAIN ANALYZE — Quimia-BD

Evidência de performance medida em 2026-10-29: 4 consultas do projeto, com `EXPLAIN (ANALYZE, BUFFERS)`, plano real, diagnóstico e, quando cabe, comparação antes/depois de índice. Os planos abaixo são a saída literal do PostgreSQL; nenhum foi editado.

## Resumo

| # | Consulta | Antes | Depois | Ganho | Índice |
|---|---|---|---|---|---|
| 1 | `fn_match_produtos` — consulta principal (massa temporária) | 33,9 ms · 1.475 buffers | 0,30 ms · 29 buffers | ~113× | `idx_fds_id_produto`, `idx_fds_produto_ativo`, `idx_fds_composto_id_fds` — **já aplicados** pelo `setup_data` |
| 2 | DAU dos últimos 7 dias (dados reais, 44.968 sessões) | 4,66 ms · 331 buffers | 0,67 ms · 14 buffers | ~7× | `idx_sessao_acesso_ocorreu_em` — **já aplicado** |
| 3 | `vw_fato_historico_recomendacao` (view de fato) e histórico por usuário | view inteira: 126 ms (60 mil linhas) · por usuário: 5,64 ms · 549 buffers | por usuário: 0,023 ms · 23 buffers | ~245× (só por usuário) | candidato `idx_historico_recomendacao_usuario_data` — **não aplicado** |
| 4 | Busca de produto: código de barras e nome | barras: 0,05 ms (já indexado) · nome `ILIKE`: 11,5 ms · 283 buffers | nome com GIN trigram: 0,30 ms · 46 buffers | ~39× (só por nome) | candidato `idx_produto_nome_trgm` — **não aplicado** |
| extra | `vw_sequencia_uso` filtrada por usuário (`WITH RECURSIVE`) | 622,7 ms | 0,64 ms (consulta reescrita) | ~970× | nenhum novo |

Os ganhos vêm de uma única amostra por consulta (a 2ª execução, com cache aquecido). Vale a forma do plano e os buffers; o milissegundo exato varia de uma execução para outra.

## Ambiente de teste

| Item | Valor |
|---|---|
| Servidor | PostgreSQL 16.15 (container `quimia-pg-local`, porta 5433) |
| Banco | `quimia_restore_test`: restore do dump da Aiven (ver [backup_recovery.md](backup_recovery.md)) |
| Configuração | `shared_buffers` = 16384 páginas (128 MB), `work_mem` = 4 MB, `random_page_cost` = 4, `enable_seqscan` = on, `max_parallel_workers_per_gather` = 2 |
| Aiven | **não foi usada** em nenhuma medição |
| Método | cada consulta roda duas vezes; vale a 2ª |

**Dados reais do banco**: `produto` 120, `historico_recomendacao` 217, `sessao_acesso` 44.968, `incompatibilidade_regra` 89. As tabelas `fds` e `fds_composto` estão **vazias** (a carga de FDS pelo `raw_json` ainda não foi feita), então com os dados reais `fn_match_produtos` sempre devolve `nao_avaliado` sem executar a consulta principal (plano 1.3 abaixo).

**Massa temporária** (estratégia de volume, sem `enable_seqscan = off`): com ~100 a ~200 linhas o planner escolhe `Seq Scan` corretamente, então não há índice a demonstrar. Para medir a diferença, os testes 1, 3 e 4 rodam sobre massa sintética criada **dentro de uma transação com `ROLLBACK`**. Todos os `DROP INDEX` / `CREATE INDEX` abaixo também ficam dentro dela. Verificado depois do rollback: `produto` = 120, `fds` = 0, `historico_recomendacao` = 217, os 4 índices originais presentes e `log_auditoria` inalterada.

```sql
BEGIN;
SET LOCAL session_replication_role = replica;  -- sem disparar auditoria / raw_json nesta carga
INSERT INTO produto (nome, id_marca, tipo_produto, cod_barras)
SELECT 'Produto temp ' || g, 1 + g % 92, 'outro', 'TMP' || lpad(g::text, 10, '0') FROM generate_series(1, 30000) g;
INSERT INTO fds (id_produto, versao, ativo) SELECT id, 'tmp', true FROM produto;                     -- 30.120
INSERT INTO fds_composto (id_fds, id_substancia)
SELECT f.id, 1 + (f.id * 7 + k * 3) % 15 FROM fds f, generate_series(1, 3) k;                        -- 90.360
INSERT INTO fds_incompatibilidade (id_fds, id_substancia, severidade, descricao_risco)
SELECT f.id, 1 + (f.id * 5) % 15, 'alta', 'tmp' FROM fds f WHERE f.id % 3 = 0;                       -- 10.040
-- historico_recomendacao: +60.000 linhas distribuídas entre os produtos e os 819 usuários (total 60.217)
ANALYZE produto; ANALYZE fds; ANALYZE fds_composto; ANALYZE fds_incompatibilidade; ANALYZE historico_recomendacao;
-- ... medições ...
ROLLBACK;
```

**Limitações**: a massa é sintética e uniforme; o container roda em Docker no Windows; os tempos absolutos não valem para a Aiven. `vw_funil_scan` e `evento_app` não existem no repositório, então o DAU (`vw_dau`) e o scan por código de barras ocupam o lugar do funil de scan.

---

## Query 1 — `fn_match_produtos`

Motor de detecção de mistura perigosa ([fn_match.sql](../src/database/sql/routines/functions/fn_match.sql)). Parâmetros: produto A = 1, produto B = 2, um par que de fato casa e devolve 7 linhas `incompativel` (regras 21, 48, 39, 83, 24, 82 e 88).

### 1.0 Por que `EXPLAIN` da function não basta

```text
Function Scan on fn_match_produtos  (cost=0.25..10.25 rows=1000 width=100) (actual time=1.355..1.356 rows=7 loops=1)
  Buffers: shared hit=101
Planning Time: 0.033 ms
Execution Time: 1.386 ms
```

Só aparece um `Function Scan`: a estimativa (`rows=1000`) é o valor padrão para funções e as consultas internas ficam escondidas. Por isso a análise abaixo usa as consultas do corpo da function, executadas separadamente com os mesmos parâmetros.

### 1.1 Verificação inicial (`EXISTS` de compostos do produto A)

```text
Result  (cost=8.32..8.33 rows=1 width=1) (actual time=0.025..0.026 rows=1 loops=1)
  Buffers: shared hit=6
  InitPlan 1 (returns $1)
    ->  Nested Loop  (cost=0.58..23.81 rows=3 width=0) (actual time=0.022..0.023 rows=1 loops=1)
          Buffers: shared hit=6
          ->  Index Scan using idx_fds_produto_ativo on fds f  (cost=0.29..8.30 rows=1 width=4) (actual time=0.013..0.013 rows=1 loops=1)
                Index Cond: (id_produto = 1)
                Buffers: shared hit=3
          ->  Index Scan using idx_fds_composto_id_fds on fds_composto fc  (cost=0.29..15.48 rows=3 width=4) (actual time=0.006..0.006 rows=1 loops=1)
                Index Cond: (id_fds = f.id)
                Filter: (id_substancia IS NOT NULL)
                Buffers: shared hit=3
Planning:
  Buffers: shared hit=12
Planning Time: 0.334 ms
Execution Time: 0.078 ms
```

Usa `idx_fds_produto_ativo` e `idx_fds_composto_id_fds`: 0,078 ms, 6 buffers. Sem os índices o resultado foi 0,050 ms, igual dentro do ruído: o produto 1 é a primeira linha da tabela e o `EXISTS` para no primeiro acerto, então o `Seq Scan` encontra a linha de imediato. A diferença real aparece na consulta principal.

### 1.2 Consulta principal (CTEs `compostos_a/b`, `classes_a/b`, `regras_batidas`, `fds_batidas`)

**Plano antes** — sem `idx_fds_id_produto`, `idx_fds_produto_ativo` e `idx_fds_composto_id_fds`:

```text
Sort  (cost=5093.21..5093.25 rows=18 width=156) (actual time=33.719..33.752 rows=7 loops=1)
  Sort Key: (CASE rb.severidade WHEN 'critica'::text THEN 1 WHEN 'alta'::text THEN 2 WHEN 'media'::text THEN 3 WHEN 'baixa'::text THEN 4 ELSE 5 END), rb.id_regra
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=1475
  CTE compostos_a
    ->  Unique  (cost=2169.36..2169.38 rows=3 width=4) (actual time=15.236..15.242 rows=3 loops=1)
          Buffers: shared hit=652
          ->  Sort  (cost=2169.36..2169.37 rows=3 width=4) (actual time=15.230..15.234 rows=3 loops=1)
                Sort Key: fc.id_substancia
                Sort Method: quicksort  Memory: 25kB
                Buffers: shared hit=652
                ->  Hash Join  (cost=539.51..2169.34 rows=3 width=4) (actual time=2.844..15.228 rows=3 loops=1)
                      Hash Cond: (fc.id_fds = f.id)
                      Buffers: shared hit=652
                      ->  Seq Scan on fds_composto fc  (cost=0.00..1392.60 rows=90360 width=8) (actual time=0.005..7.314 rows=90360 loops=1)
                            Filter: (id_substancia IS NOT NULL)
                            Buffers: shared hit=489
                      ->  Hash  (cost=539.50..539.50 rows=1 width=4) (actual time=2.831..2.833 rows=1 loops=1)
                            Buckets: 1024  Batches: 1  Memory Usage: 9kB
                            Buffers: shared hit=163
                            ->  Seq Scan on fds f  (cost=0.00..539.50 rows=1 width=4) (actual time=0.003..2.828 rows=1 loops=1)
                                  Filter: (ativo AND (id_produto = 1))
                                  Rows Removed by Filter: 30119
                                  Buffers: shared hit=163
  CTE compostos_b
    ->  Unique  (cost=2169.36..2169.38 rows=3 width=4) (actual time=15.449..15.456 rows=3 loops=1)
          Buffers: shared hit=652
          ->  Sort  (cost=2169.36..2169.37 rows=3 width=4) (actual time=15.444..15.448 rows=3 loops=1)
                Sort Key: fc_1.id_substancia
                Sort Method: quicksort  Memory: 25kB
                Buffers: shared hit=652
                ->  Hash Join  (cost=539.51..2169.34 rows=3 width=4) (actual time=2.164..15.433 rows=3 loops=1)
                      Hash Cond: (fc_1.id_fds = f_1.id)
                      Buffers: shared hit=652
                      ->  Seq Scan on fds_composto fc_1  (cost=0.00..1392.60 rows=90360 width=8) (actual time=0.009..7.829 rows=90360 loops=1)
                            Filter: (id_substancia IS NOT NULL)
                            Buffers: shared hit=489
                      ->  Hash  (cost=539.50..539.50 rows=1 width=4) (actual time=2.146..2.147 rows=1 loops=1)
                            Buckets: 1024  Batches: 1  Memory Usage: 9kB
                            Buffers: shared hit=163
                            ->  Seq Scan on fds f_1  (cost=0.00..539.50 rows=1 width=4) (actual time=0.006..2.144 rows=1 loops=1)
                                  Filter: (ativo AND (id_produto = 2))
                                  Rows Removed by Filter: 30119
                                  Buffers: shared hit=163
  CTE classes_a
    ->  HashAggregate  (cost=1.38..1.41 rows=3 width=4) (actual time=0.030..0.033 rows=5 loops=1)
          Group Key: scq.id_classe_quimica
          Batches: 1  Memory Usage: 24kB
          Buffers: shared hit=1
          ->  Hash Join  (cost=0.10..1.37 rows=3 width=4) (actual time=0.022..0.026 rows=5 loops=1)
                Hash Cond: (scq.id_substancia = ca.id_substancia)
                Buffers: shared hit=1
                ->  Seq Scan on substancia_classe_quimica scq  (cost=0.00..1.18 rows=18 width=8) (actual time=0.009..0.010 rows=18 loops=1)
                      Buffers: shared hit=1
                ->  Hash  (cost=0.06..0.06 rows=3 width=4) (actual time=0.002..0.003 rows=3 loops=1)
                      Buckets: 1024  Batches: 1  Memory Usage: 9kB
                      ->  CTE Scan on compostos_a ca  (cost=0.00..0.06 rows=3 width=4) (actual time=0.001..0.001 rows=3 loops=1)
  CTE classes_b
    ->  HashAggregate  (cost=1.38..1.41 rows=3 width=4) (actual time=0.011..0.015 rows=3 loops=1)
          Group Key: scq_1.id_classe_quimica
          Batches: 1  Memory Usage: 24kB
          Buffers: shared hit=1
          ->  Hash Join  (cost=0.10..1.37 rows=3 width=4) (actual time=0.006..0.011 rows=3 loops=1)
                Hash Cond: (scq_1.id_substancia = cb.id_substancia)
                Buffers: shared hit=1
                ->  Seq Scan on substancia_classe_quimica scq_1  (cost=0.00..1.18 rows=18 width=8) (actual time=0.001..0.002 rows=18 loops=1)
                      Buffers: shared hit=1
                ->  Hash  (cost=0.06..0.06 rows=3 width=4) (actual time=0.001..0.003 rows=3 loops=1)
                      Buckets: 1024  Batches: 1  Memory Usage: 9kB
                      ->  CTE Scan on compostos_b cb  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.001 rows=3 loops=1)
  CTE regras_batidas
    ->  Unique  (cost=51.27..51.43 rows=16 width=63) (actual time=30.837..30.847 rows=7 loops=1)
          Buffers: shared hit=1308
          ->  Sort  (cost=51.27..51.31 rows=16 width=63) (actual time=30.836..30.844 rows=7 loops=1)
                Sort Key: ir.id, ir.severidade, ir.descricao_risco
                Sort Method: quicksort  Memory: 25kB
                Buffers: shared hit=1308
                ->  Seq Scan on incompatibilidade_regra ir  (cost=0.00..50.95 rows=16 width=63) (actual time=30.802..30.837 rows=7 loops=1)
                      Filter: (ativo AND (((((id_substancia_a IS NOT NULL) AND (hashed SubPlan 6)) OR ((id_classe_a IS NOT NULL) AND (hashed SubPlan 8))) AND (((id_substancia_b IS NOT NULL) AND (hashed SubPlan 10)) OR ((id_classe_b IS NOT NULL) AND (hashed SubPlan 12)))) OR ((((id_substancia_a IS NOT NULL) AND (hashed SubPlan 14)) OR ((id_classe_a IS NOT NULL) AND (hashed SubPlan 16))) AND (((id_substancia_b IS NOT NULL) AND (hashed SubPlan 18)) OR ((id_classe_b IS NOT NULL) AND (hashed SubPlan 20))))))
                      Rows Removed by Filter: 82
                      Buffers: shared hit=1308
                      SubPlan 6
                        ->  CTE Scan on compostos_a  (cost=0.00..0.06 rows=3 width=4) (actual time=15.237..15.241 rows=3 loops=1)
                              Buffers: shared hit=652
                      SubPlan 8
                        ->  CTE Scan on classes_a  (cost=0.00..0.06 rows=3 width=4) (actual time=0.030..0.032 rows=5 loops=1)
                              Buffers: shared hit=1
                      SubPlan 10
                        ->  CTE Scan on compostos_b  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.001 rows=3 loops=1)
                      SubPlan 12
                        ->  CTE Scan on classes_b  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.001 rows=3 loops=1)
                      SubPlan 14
                        ->  CTE Scan on compostos_b compostos_b_1  (cost=0.00..0.06 rows=3 width=4) (actual time=15.451..15.456 rows=3 loops=1)
                              Buffers: shared hit=652
                      SubPlan 16
                        ->  CTE Scan on classes_b classes_b_1  (cost=0.00..0.06 rows=3 width=4) (actual time=0.011..0.012 rows=3 loops=1)
                              Buffers: shared hit=1
                      SubPlan 18
                        ->  CTE Scan on compostos_a compostos_a_1  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.001 rows=3 loops=1)
                      SubPlan 20
                        ->  CTE Scan on classes_a classes_a_1  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.001 rows=5 loops=1)
  CTE fds_batidas
    ->  Unique  (cost=698.97..698.98 rows=1 width=9) (actual time=2.847..2.852 rows=0 loops=1)
          Buffers: shared hit=167
          ->  Sort  (cost=698.97..698.97 rows=1 width=9) (actual time=2.846..2.851 rows=0 loops=1)
                Sort Key: fi.severidade, fi.descricao_risco
                Sort Method: quicksort  Memory: 25kB
                Buffers: shared hit=167
                ->  Nested Loop  (cost=0.29..698.96 rows=1 width=9) (actual time=2.838..2.843 rows=0 loops=1)
                      Buffers: shared hit=167
                      ->  Seq Scan on fds f_2  (cost=0.00..690.10 rows=1 width=8) (actual time=0.008..2.821 rows=2 loops=1)
                            Filter: (ativo AND (id_produto = ANY ('{1,2}'::integer[])) AND ((id_produto = 1) OR (id_produto = 2)))
                            Rows Removed by Filter: 30118
                            Buffers: shared hit=163
                      ->  Index Scan using idx_fds_incompat_id_fds on fds_incompatibilidade fi  (cost=0.29..8.85 rows=1 width=21) (actual time=0.006..0.008 rows=0 loops=2)
                            Index Cond: (id_fds = f_2.id)
                            Filter: ((((id_substancia IS NOT NULL) AND (hashed SubPlan 23)) OR ((id_classe_quimica IS NOT NULL) AND (hashed SubPlan 25)) OR ((id_substancia IS NOT NULL) AND (hashed SubPlan 27)) OR ((id_classe_quimica IS NOT NULL) AND (hashed SubPlan 29))) AND (((f_2.id_produto = 1) AND (((id_substancia IS NOT NULL) AND (hashed SubPlan 23)) OR ((id_classe_quimica IS NOT NULL) AND (hashed SubPlan 25)))) OR ((f_2.id_produto = 2) AND (((id_substancia IS NOT NULL) AND (hashed SubPlan 27)) OR ((id_classe_quimica IS NOT NULL) AND (hashed SubPlan 29))))))
                            Buffers: shared hit=4
                            SubPlan 23
                              ->  CTE Scan on compostos_b compostos_b_2  (cost=0.00..0.06 rows=3 width=4) (never executed)
                            SubPlan 25
                              ->  CTE Scan on classes_b classes_b_2  (cost=0.00..0.06 rows=3 width=4) (never executed)
                            SubPlan 27
                              ->  CTE Scan on compostos_a compostos_a_2  (cost=0.00..0.06 rows=3 width=4) (never executed)
                            SubPlan 29
                              ->  CTE Scan on classes_a classes_a_2  (cost=0.00..0.06 rows=3 width=4) (never executed)
  ->  Result  (cost=0.00..0.84 rows=18 width=156) (actual time=30.844..33.712 rows=7 loops=1)
        Buffers: shared hit=1475
        ->  Append  (cost=0.00..0.48 rows=18 width=152) (actual time=30.841..33.705 rows=7 loops=1)
              Buffers: shared hit=1475
              ->  CTE Scan on regras_batidas rb  (cost=0.00..0.32 rows=16 width=152) (actual time=30.840..30.844 rows=7 loops=1)
                    Buffers: shared hit=1308
              ->  CTE Scan on fds_batidas fb  (cost=0.00..0.02 rows=1 width=152) (actual time=2.849..2.849 rows=0 loops=1)
                    Buffers: shared hit=167
              ->  Result  (cost=0.04..0.05 rows=1 width=152) (actual time=0.006..0.007 rows=0 loops=1)
                    One-Time Filter: ((NOT $32) AND (NOT $33))
                    InitPlan 31 (returns $32)
                      ->  CTE Scan on regras_batidas  (cost=0.00..0.32 rows=16 width=0) (actual time=0.003..0.003 rows=1 loops=1)
                    InitPlan 32 (returns $33)
                      ->  CTE Scan on fds_batidas  (cost=0.00..0.02 rows=1 width=0) (never executed)
Planning:
  Buffers: shared hit=24
Planning Time: 0.668 ms
Execution Time: 33.916 ms
```

**Diagnóstico**

- `compostos_a` e `compostos_b` fazem `Seq Scan` em `fds_composto` (90.360 linhas, ~7,5 ms) e em `fds` (30.120 linhas, `Rows Removed by Filter: 30119`) para achar **uma** FDS: ~15 ms cada, com `Hash Join`.
- O `Seq Scan` de `incompatibilidade_regra` marca ~30,8 ms para ler 89 linhas. Esse tempo inclui a execução sob demanda dos dois CTEs de compostos, lidos pelos `hashed SubPlan`; ele não é custo da tabela de regras.
- `fds_batidas` varre `fds` inteira de novo (`Rows Removed by Filter: 30118`).
- Total: **33,9 ms e 1.475 buffers**, e o custo cresce linearmente com o número de FDS.

**Índices**: os três já estão no `setup_data` ([idx_fds_id_produto](../src/database/sql/indexes/idx_fds_id_produto.sql), [idx_fds_produto_ativo](../src/database/sql/indexes/idx_fds_produto_ativo.sql) parcial `WHERE ativo = TRUE`, [idx_fds_composto_id_fds](../src/database/sql/indexes/idx_fds_composto_id_fds.sql)). Recriados a partir desses mesmos arquivos para a medição "depois". **Nenhum índice novo é necessário.**

**Plano depois** — com os três índices (estado atual do repositório):

```text
Sort  (cost=124.67..124.72 rows=18 width=156) (actual time=0.147..0.153 rows=7 loops=1)
  Sort Key: (CASE rb.severidade WHEN 'critica'::text THEN 1 WHEN 'alta'::text THEN 2 WHEN 'media'::text THEN 3 WHEN 'baixa'::text THEN 4 ELSE 5 END), rb.id_regra
  Sort Method: quicksort  Memory: 25kB
  Buffers: shared hit=29
  CTE compostos_a
    ->  Unique  (cost=23.84..23.85 rows=3 width=4) (actual time=0.024..0.026 rows=3 loops=1)
          Buffers: shared hit=8
          ->  Sort  (cost=23.84..23.84 rows=3 width=4) (actual time=0.022..0.022 rows=3 loops=1)
                Sort Key: fc.id_substancia
                Sort Method: quicksort  Memory: 25kB
                Buffers: shared hit=8
                ->  Nested Loop  (cost=0.58..23.81 rows=3 width=4) (actual time=0.013..0.019 rows=3 loops=1)
                      Buffers: shared hit=8
                      ->  Index Scan using idx_fds_produto_ativo on fds f  (cost=0.29..8.30 rows=1 width=4) (actual time=0.007..0.008 rows=1 loops=1)
                            Index Cond: (id_produto = 1)
                            Buffers: shared hit=3
                      ->  Index Scan using idx_fds_composto_id_fds on fds_composto fc  (cost=0.29..15.48 rows=3 width=8) (actual time=0.004..0.009 rows=3 loops=1)
                            Index Cond: (id_fds = f.id)
                            Filter: (id_substancia IS NOT NULL)
                            Buffers: shared hit=5
  CTE compostos_b
    ->  Unique  (cost=23.84..23.85 rows=3 width=4) (actual time=0.006..0.007 rows=3 loops=1)
          Buffers: shared hit=8
          ->  Sort  (cost=23.84..23.84 rows=3 width=4) (actual time=0.006..0.006 rows=3 loops=1)
                Sort Key: fc_1.id_substancia
                Sort Method: quicksort  Memory: 25kB
                Buffers: shared hit=8
                ->  Nested Loop  (cost=0.58..23.81 rows=3 width=4) (actual time=0.003..0.005 rows=3 loops=1)
                      Buffers: shared hit=8
                      ->  Index Scan using idx_fds_produto_ativo on fds f_1  (cost=0.29..8.30 rows=1 width=4) (actual time=0.001..0.002 rows=1 loops=1)
                            Index Cond: (id_produto = 2)
                            Buffers: shared hit=3
                      ->  Index Scan using idx_fds_composto_id_fds on fds_composto fc_1  (cost=0.29..15.48 rows=3 width=8) (actual time=0.001..0.003 rows=3 loops=1)
                            Index Cond: (id_fds = f_1.id)
                            Filter: (id_substancia IS NOT NULL)
                            Buffers: shared hit=5
  CTE classes_a
    ->  HashAggregate  (cost=1.38..1.41 rows=3 width=4) (actual time=0.016..0.018 rows=5 loops=1)
          Group Key: scq.id_classe_quimica
          Batches: 1  Memory Usage: 24kB
          Buffers: shared hit=1
          ->  Hash Join  (cost=0.10..1.37 rows=3 width=4) (actual time=0.010..0.013 rows=5 loops=1)
                Hash Cond: (scq.id_substancia = ca.id_substancia)
                Buffers: shared hit=1
                ->  Seq Scan on substancia_classe_quimica scq  (cost=0.00..1.18 rows=18 width=8) (actual time=0.003..0.004 rows=18 loops=1)
                      Buffers: shared hit=1
                ->  Hash  (cost=0.06..0.06 rows=3 width=4) (actual time=0.002..0.002 rows=3 loops=1)
                      Buckets: 1024  Batches: 1  Memory Usage: 9kB
                      ->  CTE Scan on compostos_a ca  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.001 rows=3 loops=1)
  CTE classes_b
    ->  HashAggregate  (cost=1.38..1.41 rows=3 width=4) (actual time=0.007..0.008 rows=3 loops=1)
          Group Key: scq_1.id_classe_quimica
          Batches: 1  Memory Usage: 24kB
          Buffers: shared hit=1
          ->  Hash Join  (cost=0.10..1.37 rows=3 width=4) (actual time=0.004..0.006 rows=3 loops=1)
                Hash Cond: (scq_1.id_substancia = cb.id_substancia)
                Buffers: shared hit=1
                ->  Seq Scan on substancia_classe_quimica scq_1  (cost=0.00..1.18 rows=18 width=8) (actual time=0.001..0.002 rows=18 loops=1)
                      Buffers: shared hit=1
                ->  Hash  (cost=0.06..0.06 rows=3 width=4) (actual time=0.001..0.001 rows=3 loops=1)
                      Buckets: 1024  Batches: 1  Memory Usage: 9kB
                      ->  CTE Scan on compostos_b cb  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.001 rows=3 loops=1)
  CTE regras_batidas
    ->  Unique  (cost=51.27..51.43 rows=16 width=63) (actual time=0.116..0.118 rows=7 loops=1)
          Buffers: shared hit=20
          ->  Sort  (cost=51.27..51.31 rows=16 width=63) (actual time=0.115..0.117 rows=7 loops=1)
                Sort Key: ir.id, ir.severidade, ir.descricao_risco
                Sort Method: quicksort  Memory: 25kB
                Buffers: shared hit=20
                ->  Seq Scan on incompatibilidade_regra ir  (cost=0.00..50.95 rows=16 width=63) (actual time=0.087..0.111 rows=7 loops=1)
                      Filter: (ativo AND (((((id_substancia_a IS NOT NULL) AND (hashed SubPlan 6)) OR ((id_classe_a IS NOT NULL) AND (hashed SubPlan 8))) AND (((id_substancia_b IS NOT NULL) AND (hashed SubPlan 10)) OR ((id_classe_b IS NOT NULL) AND (hashed SubPlan 12)))) OR ((((id_substancia_a IS NOT NULL) AND (hashed SubPlan 14)) OR ((id_classe_a IS NOT NULL) AND (hashed SubPlan 16))) AND (((id_substancia_b IS NOT NULL) AND (hashed SubPlan 18)) OR ((id_classe_b IS NOT NULL) AND (hashed SubPlan 20))))))
                      Rows Removed by Filter: 82
                      Buffers: shared hit=20
                      SubPlan 6
                        ->  CTE Scan on compostos_a  (cost=0.00..0.06 rows=3 width=4) (actual time=0.024..0.026 rows=3 loops=1)
                              Buffers: shared hit=8
                      SubPlan 8
                        ->  CTE Scan on classes_a  (cost=0.00..0.06 rows=3 width=4) (actual time=0.016..0.018 rows=5 loops=1)
                              Buffers: shared hit=1
                      SubPlan 10
                        ->  CTE Scan on compostos_b  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.000 rows=3 loops=1)
                      SubPlan 12
                        ->  CTE Scan on classes_b  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.000 rows=3 loops=1)
                      SubPlan 14
                        ->  CTE Scan on compostos_b compostos_b_1  (cost=0.00..0.06 rows=3 width=4) (actual time=0.006..0.007 rows=3 loops=1)
                              Buffers: shared hit=8
                      SubPlan 16
                        ->  CTE Scan on classes_b classes_b_1  (cost=0.00..0.06 rows=3 width=4) (actual time=0.007..0.008 rows=3 loops=1)
                              Buffers: shared hit=1
                      SubPlan 18
                        ->  CTE Scan on compostos_a compostos_a_1  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.000 rows=3 loops=1)
                      SubPlan 20
                        ->  CTE Scan on classes_a classes_a_1  (cost=0.00..0.06 rows=3 width=4) (actual time=0.000..0.000 rows=5 loops=1)
  CTE fds_batidas
    ->  Unique  (cost=21.49..21.50 rows=1 width=9) (actual time=0.013..0.014 rows=0 loops=1)
          Buffers: shared hit=9
          ->  Sort  (cost=21.49..21.49 rows=1 width=9) (actual time=0.013..0.013 rows=0 loops=1)
                Sort Key: fi.severidade, fi.descricao_risco
                Sort Method: quicksort  Memory: 25kB
                Buffers: shared hit=9
                ->  Nested Loop  (cost=0.57..21.48 rows=1 width=9) (actual time=0.011..0.012 rows=0 loops=1)
                      Buffers: shared hit=9
                      ->  Index Scan using idx_fds_id_produto on fds f_2  (cost=0.29..12.62 rows=1 width=8) (actual time=0.005..0.007 rows=2 loops=1)
                            Index Cond: (id_produto = ANY ('{1,2}'::integer[]))
                            Filter: ativo
                            Buffers: shared hit=5
                      ->  Index Scan using idx_fds_incompat_id_fds on fds_incompatibilidade fi  (cost=0.29..8.85 rows=1 width=21) (actual time=0.002..0.002 rows=0 loops=2)
                            Index Cond: (id_fds = f_2.id)
                            Filter: ((((id_substancia IS NOT NULL) AND (hashed SubPlan 23)) OR ((id_classe_quimica IS NOT NULL) AND (hashed SubPlan 25)) OR ((id_substancia IS NOT NULL) AND (hashed SubPlan 27)) OR ((id_classe_quimica IS NOT NULL) AND (hashed SubPlan 29))) AND (((f_2.id_produto = 1) AND (((id_substancia IS NOT NULL) AND (hashed SubPlan 23)) OR ((id_classe_quimica IS NOT NULL) AND (hashed SubPlan 25)))) OR ((f_2.id_produto = 2) AND (((id_substancia IS NOT NULL) AND (hashed SubPlan 27)) OR ((id_classe_quimica IS NOT NULL) AND (hashed SubPlan 29))))))
                            Buffers: shared hit=4
                            SubPlan 23
                              ->  CTE Scan on compostos_b compostos_b_2  (cost=0.00..0.06 rows=3 width=4) (never executed)
                            SubPlan 25
                              ->  CTE Scan on classes_b classes_b_2  (cost=0.00..0.06 rows=3 width=4) (never executed)
                            SubPlan 27
                              ->  CTE Scan on compostos_a compostos_a_2  (cost=0.00..0.06 rows=3 width=4) (never executed)
                            SubPlan 29
                              ->  CTE Scan on classes_a classes_a_2  (cost=0.00..0.06 rows=3 width=4) (never executed)
  ->  Result  (cost=0.00..0.84 rows=18 width=156) (actual time=0.120..0.142 rows=7 loops=1)
        Buffers: shared hit=29
        ->  Append  (cost=0.00..0.48 rows=18 width=152) (actual time=0.118..0.138 rows=7 loops=1)
              Buffers: shared hit=29
              ->  CTE Scan on regras_batidas rb  (cost=0.00..0.32 rows=16 width=152) (actual time=0.118..0.121 rows=7 loops=1)
                    Buffers: shared hit=20
              ->  CTE Scan on fds_batidas fb  (cost=0.00..0.02 rows=1 width=152) (actual time=0.013..0.014 rows=0 loops=1)
                    Buffers: shared hit=9
              ->  Result  (cost=0.04..0.05 rows=1 width=152) (actual time=0.001..0.002 rows=0 loops=1)
                    One-Time Filter: ((NOT $34) AND (NOT $35))
                    InitPlan 31 (returns $34)
                      ->  CTE Scan on regras_batidas  (cost=0.00..0.32 rows=16 width=0) (actual time=0.000..0.000 rows=1 loops=1)
                    InitPlan 32 (returns $35)
                      ->  CTE Scan on fds_batidas  (cost=0.00..0.02 rows=1 width=0) (never executed)
Planning:
  Buffers: shared hit=36
Planning Time: 1.269 ms
Execution Time: 0.299 ms
```

**Conclusão**

- Cada busca por produto vira dois `Index Scan` (3 buffers em `fds` + 5 em `fds_composto`); as estimativas batem com o real (`rows=1` em `fds`, `rows=3` em `fds_composto`).
- **33,9 ms → 0,30 ms (~113×); 1.475 → 29 buffers.**
- O `Seq Scan` em `incompatibilidade_regra` (89 linhas, 82 descartadas) e em `substancia_classe_quimica` (18 linhas) é a escolha correta: tabelas pequenas, um índice não ajudaria.
- O tempo de planejamento (1,27 ms) passa o de execução (0,30 ms): a function é barata, o custo está em planejar a consulta com 6 CTEs.

### 1.3 Com os dados reais (FDS vazia)

```text
Function Scan on fn_match_produtos  (cost=0.25..10.25 rows=1000 width=100) (actual time=0.511..0.512 rows=1 loops=1)
  Buffers: shared hit=121
Planning Time: 0.008 ms
Execution Time: 0.914 ms
```

Retorna `nao_avaliado` pelo primeiro `IF` da function, sem tocar nas consultas acima. A análise 1.1 e 1.2 vale para quando as FDS forem carregadas.

---

## Query 2 — DAU (`vw_dau`)

[vw_dau.sql](../src/database/sql/data_mart/facts/vw_dau.sql): `COUNT(DISTINCT id_usuario)` por `ocorreu_em::date` em `sessao_acesso`. Dados **reais**: 44.968 linhas, 360 dias.

### 2.1 View filtrada por data

```sql
SELECT * FROM vw_dau WHERE data >= CURRENT_DATE - 7 ORDER BY data;
```

```text
GroupAggregate  (cost=2307.44..2607.16 rows=14984 width=12) (actual time=6.395..6.518 rows=8 loops=1)
  Group Key: ((sessao_acesso.ocorreu_em)::date)
  Buffers: shared hit=331
  ->  Sort  (cost=2307.44..2344.91 rows=14989 width=20) (actual time=6.367..6.403 rows=1139 loops=1)
        Sort Key: ((sessao_acesso.ocorreu_em)::date), sessao_acesso.id_usuario
        Sort Method: quicksort  Memory: 102kB
        Buffers: shared hit=331
        ->  Seq Scan on sessao_acesso  (cost=0.00..1267.83 rows=14989 width=20) (actual time=5.738..6.047 rows=1139 loops=1)
              Filter: ((ocorreu_em)::date >= (CURRENT_DATE - 7))
              Rows Removed by Filter: 43829
              Buffers: shared hit=331
Planning Time: 0.078 ms
Execution Time: 6.544 ms
```

**Diagnóstico**: o filtro vira `(ocorreu_em)::date >= (CURRENT_DATE - 7)`, uma função aplicada à coluna, e não usa `idx_sessao_acesso_ocorreu_em`. Resultado: `Seq Scan`, 43.829 linhas descartadas para devolver 1.139, e estimativa errada (14.989 estimadas contra 1.139 reais, porque o planner não tem estatística da expressão). 6,5 ms, 331 buffers.

### 2.2 Mesma consulta com intervalo sobre a coluna

```sql
SELECT ocorreu_em::date AS data, COUNT(DISTINCT id_usuario) AS usuarios_ativos
FROM sessao_acesso
WHERE ocorreu_em >= CURRENT_DATE - 7
GROUP BY ocorreu_em::date ORDER BY data;
```

**Antes** — sem `idx_sessao_acesso_ocorreu_em` (`DROP INDEX` temporário na transação):

```text
GroupAggregate  (cost=1181.04..1204.62 rows=1179 width=12) (actual time=4.479..4.636 rows=8 loops=1)
  Group Key: ((ocorreu_em)::date)
  Buffers: shared hit=331
  ->  Sort  (cost=1181.04..1183.98 rows=1179 width=20) (actual time=4.446..4.493 rows=1139 loops=1)
        Sort Key: ((ocorreu_em)::date), id_usuario
        Sort Method: quicksort  Memory: 102kB
        Buffers: shared hit=331
        ->  Seq Scan on sessao_acesso  (cost=0.00..1120.89 rows=1179 width=20) (actual time=3.943..4.148 rows=1139 loops=1)
              Filter: (ocorreu_em >= (CURRENT_DATE - 7))
              Rows Removed by Filter: 43829
              Buffers: shared hit=331
Planning Time: 0.103 ms
Execution Time: 4.657 ms
```

**Depois** — com o índice (estado atual do repositório):

```text
GroupAggregate  (cost=112.02..135.60 rows=1179 width=12) (actual time=0.530..0.651 rows=8 loops=1)
  Group Key: ((ocorreu_em)::date)
  Buffers: shared hit=14
  ->  Sort  (cost=112.02..114.97 rows=1179 width=20) (actual time=0.508..0.544 rows=1139 loops=1)
        Sort Key: ((ocorreu_em)::date), id_usuario
        Sort Method: quicksort  Memory: 102kB
        Buffers: shared hit=14
        ->  Index Scan using idx_sessao_acesso_ocorreu_em on sessao_acesso  (cost=0.29..51.87 rows=1179 width=20) (actual time=0.014..0.258 rows=1139 loops=1)
              Index Cond: (ocorreu_em >= (CURRENT_DATE - 7))
              Buffers: shared hit=14
Planning Time: 0.086 ms
Execution Time: 0.669 ms
```

**Conclusão**: o índice existente funciona quando o filtro é um intervalo sobre `ocorreu_em`: `Seq Scan` (331 buffers, 4,66 ms) → `Index Scan` (14 buffers, 0,67 ms), ~7×. Para ler a série inteira (360 linhas), a própria `vw_dau` é adequada. Para janelas recentes, o consumidor deve filtrar por intervalo em `ocorreu_em`, e não pela coluna `data` da view. Não alterei a view: é uma recomendação de uso.

### 2.3 Extra: `vw_sequencia_uso` por usuário

[vw_sequencia_uso.sql](../src/database/sql/data_mart/facts/vw_sequencia_uso.sql) (`WITH RECURSIVE`, criada na etapa de conformidade):

```sql
SELECT * FROM vw_sequencia_uso WHERE id_usuario = '<usuario>';
```

```text
HashAggregate  (cost=734245.61..734247.61 rows=200 width=28) (actual time=618.523..618.540 rows=90 loops=1)
  Group Key: sequencia.inicio
  Batches: 1  Memory Usage: 48kB
  Buffers: shared hit=331
  CTE dias
    ->  HashAggregate  (cost=1117.94..1678.95 rows=44881 width=20) (actual time=182.917..191.290 rows=37862 loops=1)
          Group Key: sessao_acesso.id_usuario, (sessao_acesso.ocorreu_em)::date
          Batches: 1  Memory Usage: 4369kB
          Buffers: shared hit=331
          ->  Seq Scan on sessao_acesso  (cost=0.00..893.10 rows=44968 width=20) (actual time=161.126..165.626 rows=44968 loops=1)
                Buffers: shared hit=331
  CTE sequencia
    ->  Recursive Union  (cost=8731.07..646687.26 rows=3810511 width=28) (actual time=241.271..610.285 rows=37862 loops=1)
          Buffers: shared hit=331
          ->  Merge Anti Join  (cost=8731.07..10132.27 rows=33661 width=28) (actual time=241.268..256.270 rows=27452 loops=1)
                Merge Cond: ((d.id_usuario = v.id_usuario) AND (((d.dia - 1)) = v.dia))
                Buffers: shared hit=331
                ->  Sort  (cost=4365.53..4477.74 rows=44881 width=20) (actual time=224.615..229.668 rows=37862 loops=1)
                      Sort Key: d.id_usuario, ((d.dia - 1))
                      Sort Method: quicksort  Memory: 3141kB
                      Buffers: shared hit=331
                      ->  CTE Scan on dias d  (cost=0.00..897.62 rows=44881 width=20) (actual time=182.921..202.360 rows=37862 loops=1)
                            Buffers: shared hit=331
                ->  Sort  (cost=4365.53..4477.74 rows=44881 width=20) (actual time=16.561..20.346 rows=37862 loops=1)
                      Sort Key: v.id_usuario, v.dia
                      Sort Method: quicksort  Memory: 3141kB
                      ->  CTE Scan on dias v  (cost=0.00..897.62 rows=44881 width=20) (actual time=0.002..2.344 rows=37862 loops=1)
          ->  Merge Join  (cost=50056.74..59844.99 rows=377685 width=28) (actual time=20.065..24.939 rows=744 loops=14)
                Merge Cond: ((d_1.id_usuario = s.id_usuario) AND (d_1.dia = ((s.dia + 1))))
                ->  Sort  (cost=4365.53..4477.74 rows=44881 width=20) (actual time=17.226..19.959 rows=34265 loops=14)
                      Sort Key: d_1.id_usuario, d_1.dia
                      Sort Method: quicksort  Memory: 3141kB
                      ->  CTE Scan on dias d_1  (cost=0.00..897.62 rows=44881 width=20) (actual time=0.004..3.327 rows=37862 loops=14)
                ->  Materialize  (cost=45691.21..47374.26 rows=336610 width=28) (actual time=1.788..2.157 rows=2704 loops=14)
                      ->  Sort  (cost=45691.21..46532.73 rows=336610 width=28) (actual time=1.780..1.878 rows=2704 loops=14)
                            Sort Key: s.id_usuario, ((s.dia + 1))
                            Sort Method: quicksort  Memory: 25kB
                            ->  WorkTable Scan on sequencia s  (cost=0.00..6732.20 rows=336610 width=28) (actual time=0.730..0.947 rows=2704 loops=14)
  ->  CTE Scan on sequencia  (cost=0.00..85736.50 rows=19053 width=28) (actual time=241.290..618.409 rows=182 loops=1)
        Filter: (id_usuario = '0015b9a8-33bb-4099-a3ba-546a16606060'::uuid)
        Rows Removed by Filter: 37680
        Buffers: shared hit=331
Planning Time: 0.149 ms
JIT:
  Functions: 40
  Options: Inlining true, Optimization true, Expressions true, Deforming true
  Timing: Generation 1.138 ms, Inlining 7.715 ms, Optimization 87.028 ms, Emission 76.635 ms, Total 172.516 ms
Execution Time: 622.698 ms
```

**Diagnóstico**: um CTE recursivo não recebe o filtro de fora. A view calcula as sequências de **todos** os usuários (`dias` com 37.862 linhas, 14 iterações da recursão) e só o `CTE Scan` final aplica `id_usuario = ...` (`Rows Removed by Filter: 37680`). O custo estimado alto (734 mil) acionou o JIT: 172,5 ms dos 622,7 ms.

**Reescrita** com o filtro dentro do CTE `dias` (mesmas 90 linhas de resultado, validado contra a view):

```text
HashAggregate  (cost=2102.32..2104.32 rows=200 width=28) (actual time=0.601..0.611 rows=90 loops=1)
  Group Key: sequencia.id_usuario, sequencia.inicio
  Batches: 1  Memory Usage: 48kB
  Buffers: shared hit=179
  CTE dias
    ->  HashAggregate  (cost=332.31..335.40 rows=247 width=20) (actual time=0.187..0.205 rows=182 loops=1)
          Group Key: (sessao_acesso.ocorreu_em)::date
          Batches: 1  Memory Usage: 45kB
          Buffers: shared hit=179
          ->  Bitmap Heap Scan on sessao_acesso  (cost=6.20..331.70 rows=247 width=20) (actual time=0.022..0.158 rows=236 loops=1)
                Recheck Cond: (id_usuario = '0015b9a8-33bb-4099-a3ba-546a16606060'::uuid)
                Heap Blocks: exact=177
                Buffers: shared hit=179
                ->  Bitmap Index Scan on idx_sessao_acesso_id_usuario  (cost=0.00..6.14 rows=247 width=0) (actual time=0.010..0.010 rows=236 loops=1)
                      Index Cond: (id_usuario = '0015b9a8-33bb-4099-a3ba-546a16606060'::uuid)
                      Buffers: shared hit=2
  CTE sequencia
    ->  Recursive Union  (cost=8.64..1758.07 rows=295 width=28) (actual time=0.243..0.537 rows=182 loops=1)
          Buffers: shared hit=179
          ->  Hash Anti Join  (cost=8.64..22.55 rows=185 width=28) (actual time=0.242..0.276 rows=90 loops=1)
                Hash Cond: ((d.id_usuario = v.id_usuario) AND ((d.dia - 1) = v.dia))
                Buffers: shared hit=179
                ->  CTE Scan on dias d  (cost=0.00..4.94 rows=247 width=20) (actual time=0.188..0.197 rows=182 loops=1)
                      Buffers: shared hit=179
                ->  Hash  (cost=4.94..4.94 rows=247 width=20) (actual time=0.051..0.051 rows=182 loops=1)
                      Buckets: 1024  Batches: 1  Memory Usage: 18kB
                      ->  CTE Scan on dias v  (cost=0.00..4.94 rows=247 width=20) (actual time=0.000..0.038 rows=182 loops=1)
          ->  Merge Join  (cost=152.15..173.26 rows=11 width=28) (actual time=0.016..0.030 rows=12 loops=8)
                Merge Cond: ((s.id_usuario = d_1.id_usuario) AND (((s.dia + 1)) = d_1.dia))
                ->  Sort  (cost=137.39..142.02 rows=1850 width=28) (actual time=0.007..0.008 rows=23 loops=8)
                      Sort Key: s.id_usuario, ((s.dia + 1))
                      Sort Method: quicksort  Memory: 25kB
                      ->  WorkTable Scan on sequencia s  (cost=0.00..37.00 rows=1850 width=28) (actual time=0.000..0.002 rows=23 loops=8)
                ->  Sort  (cost=14.76..15.37 rows=247 width=20) (actual time=0.007..0.011 rows=140 loops=8)
                      Sort Key: d_1.id_usuario, d_1.dia
                      Sort Method: quicksort  Memory: 33kB
                      ->  CTE Scan on dias d_1  (cost=0.00..4.94 rows=247 width=20) (actual time=0.000..0.014 rows=182 loops=1)
  ->  CTE Scan on sequencia  (cost=0.00..5.90 rows=295 width=28) (actual time=0.243..0.566 rows=182 loops=1)
        Buffers: shared hit=179
Planning Time: 0.094 ms
Execution Time: 0.643 ms
```

**622,7 ms → 0,64 ms (~970×)**, usando `idx_sessao_acesso_id_usuario`. A view serve para análise do conjunto completo (BI); para consulta por usuário a forma reescrita é a indicada.

---

## Query 3 — Data Mart: `vw_fato_historico_recomendacao`

View de fato com CTE e window functions (`RANK() OVER`, `SUM(COUNT(*)) OVER`) sobre `historico_recomendacao`, junto de `dim_produto` e `dim_usuario` ([vw_fato_historico_recomendacao.sql](../src/database/sql/data_mart/facts/vw_fato_historico_recomendacao.sql)).

### 3.1 View inteira

**Volume real** (217 linhas): 0,67 ms.

```text
Hash Join  (cost=113.93..122.19 rows=130 width=243) (actual time=0.508..0.621 rows=217 loops=1)
  Hash Cond: (b.data = rtd.data)
  Buffers: shared hit=43
  CTE base
    ->  Seq Scan on historico_recomendacao hr  (cost=0.00..5.71 rows=217 width=39) (actual time=0.003..0.025 rows=217 loops=1)
          Buffers: shared hit=3
  ->  Hash Join  (cost=85.15..93.06 rows=130 width=203) (actual time=0.414..0.498 rows=217 loops=1)
        Hash Cond: (p.id_marca = m.id)
        Buffers: shared hit=40
        ->  Hash Join  (cost=82.08..89.63 rows=130 width=193) (actual time=0.396..0.451 rows=217 loops=1)
              Hash Cond: (base.id_produto = p.id)
              Buffers: shared hit=39
              ->  WindowAgg  (cost=15.07..18.57 rows=200 width=20) (actual time=0.052..0.079 rows=94 loops=1)
                    ->  Sort  (cost=15.07..15.57 rows=200 width=12) (actual time=0.051..0.054 rows=94 loops=1)
                          Sort Key: (count(*)) DESC
                          Sort Method: quicksort  Memory: 28kB
                          ->  HashAggregate  (cost=5.43..7.43 rows=200 width=12) (actual time=0.035..0.043 rows=94 loops=1)
                                Group Key: base.id_produto
                                Batches: 1  Memory Usage: 40kB
                                ->  CTE Scan on base  (cost=0.00..4.34 rows=217 width=4) (actual time=0.000..0.010 rows=217 loops=1)
              ->  Hash  (cost=65.39..65.39 rows=130 width=181) (actual time=0.342..0.343 rows=217 loops=1)
                    Buckets: 1024  Batches: 1  Memory Usage: 32kB
                    Buffers: shared hit=39
                    ->  Hash Join  (cost=60.13..65.39 rows=130 width=181) (actual time=0.228..0.302 rows=217 loops=1)
                          Hash Cond: (b.id_usuario = u.id)
                          Buffers: shared hit=39
                          ->  Hash Join  (cost=5.70..10.62 rows=130 width=174) (actual time=0.027..0.069 rows=217 loops=1)
                                Hash Cond: (b.id_produto = p.id)
                                Buffers: shared hit=3
                                ->  CTE Scan on base b  (cost=0.00..4.34 rows=217 width=146) (actual time=0.000..0.010 rows=217 loops=1)
                                ->  Hash  (cost=4.20..4.20 rows=120 width=28) (actual time=0.025..0.025 rows=120 loops=1)
                                      Buckets: 1024  Batches: 1  Memory Usage: 16kB
                                      Buffers: shared hit=3
                                      ->  Seq Scan on produto p  (cost=0.00..4.20 rows=120 width=28) (actual time=0.004..0.014 rows=120 loops=1)
                                            Buffers: shared hit=3
                          ->  Hash  (cost=44.19..44.19 rows=819 width=23) (actual time=0.199..0.199 rows=819 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 53kB
                                Buffers: shared hit=36
                                ->  Seq Scan on usuario u  (cost=0.00..44.19 rows=819 width=23) (actual time=0.002..0.108 rows=819 loops=1)
                                      Buffers: shared hit=36
        ->  Hash  (cost=1.92..1.92 rows=92 width=18) (actual time=0.015..0.015 rows=92 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 13kB
              Buffers: shared hit=1
              ->  Seq Scan on marca m  (cost=0.00..1.92 rows=92 width=18) (actual time=0.001..0.006 rows=92 loops=1)
                    Buffers: shared hit=1
  ->  Hash  (cost=20.57..20.57 rows=200 width=44) (actual time=0.091..0.092 rows=1 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 9kB
        Buffers: shared hit=3
        ->  Subquery Scan on rtd  (cost=15.07..20.57 rows=200 width=44) (actual time=0.090..0.091 rows=1 loops=1)
              Buffers: shared hit=3
              ->  WindowAgg  (cost=15.07..18.57 rows=200 width=44) (actual time=0.090..0.090 rows=1 loops=1)
                    Buffers: shared hit=3
                    ->  Sort  (cost=15.07..15.57 rows=200 width=12) (actual time=0.087..0.087 rows=1 loops=1)
                          Sort Key: base_1.data
                          Sort Method: quicksort  Memory: 25kB
                          Buffers: shared hit=3
                          ->  HashAggregate  (cost=5.43..7.43 rows=200 width=12) (actual time=0.084..0.085 rows=1 loops=1)
                                Group Key: base_1.data
                                Batches: 1  Memory Usage: 40kB
                                Buffers: shared hit=3
                                ->  CTE Scan on base base_1  (cost=0.00..4.34 rows=217 width=4) (actual time=0.004..0.061 rows=217 loops=1)
                                      Buffers: shared hit=3
Planning:
  Buffers: shared hit=11
Planning Time: 0.387 ms
Execution Time: 0.666 ms
```

**Massa temporária** (60.217 linhas de histórico, 30.120 produtos): 126 ms.

```text
Hash Join  (cost=5071.67..6507.95 rows=400 width=241) (actual time=83.547..123.144 rows=60217 loops=1)
  Hash Cond: (b.data = rtd.data)
  Buffers: shared hit=869, temp read=750 written=375
  CTE base
    ->  Seq Scan on historico_recomendacao hr  (cost=0.00..1301.71 rows=60217 width=39) (actual time=0.007..7.732 rows=60217 loops=1)
          Buffers: shared hit=549
  ->  Hash Join  (cost=2246.89..3682.09 rows=400 width=201) (actual time=52.403..82.018 rows=60217 loops=1)
        Hash Cond: (b.id_usuario = u.id)
        Buffers: shared hit=320, temp read=750 written=1
        ->  Hash Join  (cost=2192.46..3626.62 rows=400 width=194) (actual time=52.197..71.647 rows=60217 loops=1)
              Hash Cond: (b.id_produto = p.id)
              Buffers: shared hit=284, temp read=750 written=1
              ->  CTE Scan on base b  (cost=0.00..1204.34 rows=60217 width=146) (actual time=0.010..4.302 rows=60217 loops=1)
                    Buffers: temp read=376 written=1
              ->  Hash  (cost=2189.96..2189.96 rows=200 width=56) (actual time=52.179..52.187 rows=30120 loops=1)
                    Buckets: 32768 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 2985kB
                    Buffers: shared hit=284, temp read=374
                    ->  Hash Join  (cost=1526.14..2189.96 rows=200 width=56) (actual time=33.969..46.871 rows=30120 loops=1)
                          Hash Cond: (p.id_marca = m.id)
                          Buffers: shared hit=284, temp read=374
                          ->  Hash Join  (cost=1523.07..2186.34 rows=200 width=46) (actual time=33.944..42.705 rows=30120 loops=1)
                                Hash Cond: (p.id = rp.id_produto)
                                Buffers: shared hit=283, temp read=374
                                ->  Seq Scan on produto p  (cost=0.00..584.20 rows=30120 width=26) (actual time=0.003..1.659 rows=30120 loops=1)
                                      Buffers: shared hit=283
                                ->  Hash  (cost=1520.57..1520.57 rows=200 width=20) (actual time=33.934..33.938 rows=30120 loops=1)
                                      Buckets: 32768 (originally 1024)  Batches: 1 (originally 1)  Memory Usage: 1786kB
                                      Buffers: temp read=374
                                      ->  Subquery Scan on rp  (cost=1515.07..1520.57 rows=200 width=20) (actual time=19.470..30.986 rows=30120 loops=1)
                                            Buffers: temp read=374
                                            ->  WindowAgg  (cost=1515.07..1518.57 rows=200 width=20) (actual time=19.468..28.804 rows=30120 loops=1)
                                                  Buffers: temp read=374
                                                  ->  Sort  (cost=1515.07..1515.57 rows=200 width=12) (actual time=19.458..20.503 rows=30120 loops=1)
                                                        Sort Key: (count(*)) DESC
                                                        Sort Method: quicksort  Memory: 1945kB
                                                        Buffers: temp read=374
                                                        ->  HashAggregate  (cost=1505.42..1507.42 rows=200 width=12) (actual time=13.172..16.467 rows=30120 loops=1)
                                                              Group Key: base.id_produto
                                                              Batches: 1  Memory Usage: 3617kB
                                                              Buffers: temp read=374
                                                              ->  CTE Scan on base  (cost=0.00..1204.34 rows=60217 width=4) (actual time=0.000..3.871 rows=60217 loops=1)
                                                                    Buffers: temp read=374
                          ->  Hash  (cost=1.92..1.92 rows=92 width=18) (actual time=0.021..0.022 rows=92 loops=1)
                                Buckets: 1024  Batches: 1  Memory Usage: 13kB
                                Buffers: shared hit=1
                                ->  Seq Scan on marca m  (cost=0.00..1.92 rows=92 width=18) (actual time=0.004..0.010 rows=92 loops=1)
                                      Buffers: shared hit=1
        ->  Hash  (cost=44.19..44.19 rows=819 width=23) (actual time=0.192..0.194 rows=819 loops=1)
              Buckets: 1024  Batches: 1  Memory Usage: 53kB
              Buffers: shared hit=36
              ->  Seq Scan on usuario u  (cost=0.00..44.19 rows=819 width=23) (actual time=0.007..0.102 rows=819 loops=1)
                    Buffers: shared hit=36
  ->  Hash  (cost=1520.57..1520.57 rows=200 width=44) (actual time=31.140..31.143 rows=360 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 27kB
        Buffers: shared hit=549, temp written=374
        ->  Subquery Scan on rtd  (cost=1515.07..1520.57 rows=200 width=44) (actual time=30.923..31.103 rows=360 loops=1)
              Buffers: shared hit=549, temp written=374
              ->  WindowAgg  (cost=1515.07..1518.57 rows=200 width=44) (actual time=30.922..31.074 rows=360 loops=1)
                    Buffers: shared hit=549, temp written=374
                    ->  Sort  (cost=1515.07..1515.57 rows=200 width=12) (actual time=30.912..30.924 rows=360 loops=1)
                          Sort Key: base_1.data
                          Sort Method: quicksort  Memory: 39kB
                          Buffers: shared hit=549, temp written=374
                          ->  HashAggregate  (cost=1505.42..1507.42 rows=200 width=12) (actual time=30.833..30.864 rows=360 loops=1)
                                Group Key: base_1.data
                                Batches: 1  Memory Usage: 77kB
                                Buffers: shared hit=549, temp written=374
                                ->  CTE Scan on base base_1  (cost=0.00..1204.34 rows=60217 width=4) (actual time=0.009..23.188 rows=60217 loops=1)
                                      Buffers: shared hit=549, temp written=374
Planning:
  Buffers: shared hit=4
Planning Time: 0.480 ms
Execution Time: 125.993 ms
```

**Diagnóstico**

- A view devolve **todas** as linhas (é uma tabela de fatos), então `Seq Scan` + `Hash Join` é o plano correto; nenhum índice melhoraria uma leitura completa.
- O CTE `base` é referenciado 3 vezes: o PostgreSQL o materializa uma vez (`Seq Scan` em `historico_recomendacao`, 549 buffers) e o relê por `CTE Scan`. Acima de `work_mem` = 4 MB ele usa arquivo temporário (`temp written=374`, `temp read=750`). Todos os `Hash` ficaram em `Batches: 1`, sem derramar.
- As estimativas do planner ficam longe do real depois do `CTE Scan` (`rows=200` para 30.120 grupos; `rows=400` para 60.217 no `Hash Join` final), porque o CTE não carrega estatísticas. Não muda o plano escolhido.
- O ponto de atenção é o volume, não um índice: o custo cresce com `historico_recomendacao`. No volume atual (217) é desprezível.

### 3.2 Histórico de um usuário (tabela base)

```sql
SELECT id, id_produto, resultado, data_consulta FROM historico_recomendacao
WHERE id_usuario = '<usuario>' ORDER BY data_consulta DESC LIMIT 20;
```

**Antes** — sem índice:

```text
Limit  (cost=1303.66..1303.71 rows=20 width=27) (actual time=5.613..5.617 rows=20 loops=1)
  Buffers: shared hit=549
  ->  Sort  (cost=1303.66..1303.84 rows=73 width=27) (actual time=5.610..5.612 rows=20 loops=1)
        Sort Key: data_consulta DESC
        Sort Method: top-N heapsort  Memory: 27kB
        Buffers: shared hit=549
        ->  Seq Scan on historico_recomendacao  (cost=0.00..1301.71 rows=73 width=27) (actual time=0.011..5.580 rows=76 loops=1)
              Filter: (id_usuario = '2924805b-401c-47d6-ab36-4b476b67ec37'::uuid)
              Rows Removed by Filter: 60141
              Buffers: shared hit=549
Planning Time: 0.073 ms
Execution Time: 5.643 ms
```

**Depois** — com `CREATE INDEX idx_historico_recomendacao_usuario_data ON historico_recomendacao (id_usuario, data_consulta DESC)` (somente local):

```text
Limit  (cost=0.41..77.48 rows=20 width=27) (actual time=0.007..0.017 rows=20 loops=1)
  Buffers: shared hit=23
  ->  Index Scan using idx_historico_recomendacao_usuario_data on historico_recomendacao  (cost=0.41..281.69 rows=73 width=27) (actual time=0.007..0.016 rows=20 loops=1)
        Index Cond: (id_usuario = '2924805b-401c-47d6-ab36-4b476b67ec37'::uuid)
        Buffers: shared hit=23
Planning Time: 0.028 ms
Execution Time: 0.023 ms
```

**Conclusão**: `Seq Scan` (60.141 linhas descartadas, 549 buffers, 5,64 ms) → `Index Scan` já ordenado (23 buffers, 0,023 ms), sem `Sort`. É o mesmo padrão dos índices `usuario + data` que o projeto já tem (`idx_ponto_salvo_usuario_data`, `idx_estante_produto_estante_data`). **Não foi aplicado ao repositório**: com os 217 registros reais o `Seq Scan` custa 0,025 ms, e este repositório não contém a consulta que o usaria. Fica como candidato para quando o histórico crescer.

---

## Query 4 — Busca de produto

Não há função de busca versionada no banco (a busca fica no back-end). Foram medidos os dois acessos que um app faz sobre `produto`.

### 4.1 Scan por código de barras (`dim_produto`)

```sql
SELECT * FROM dim_produto WHERE cod_barras = 'TMP0000012345';
```

**Massa temporária** (30.120 produtos):

```text
Hash Join  (cost=8.32..18.18 rows=1 width=57) (actual time=0.027..0.035 rows=1 loops=1)
  Hash Cond: (m.id = p.id_marca)
  Buffers: shared hit=4
  ->  Seq Scan on marca m  (cost=0.00..1.92 rows=92 width=18) (actual time=0.002..0.006 rows=92 loops=1)
        Buffers: shared hit=1
  ->  Hash  (cost=8.30..8.30 rows=1 width=46) (actual time=0.019..0.019 rows=1 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 9kB
        Buffers: shared hit=3
        ->  Index Scan using produto_cod_barras_key on produto p  (cost=0.29..8.30 rows=1 width=46) (actual time=0.017..0.018 rows=1 loops=1)
              Index Cond: ((cod_barras)::text = 'TMP0000012345'::text)
              Buffers: shared hit=3
  SubPlan 1
    ->  Seq Scan on empresa_produto ep  (cost=0.00..30.75 rows=4 width=0) (actual time=0.000..0.000 rows=0 loops=1)
          Filter: ((NOT ativo) AND (id_produto = p.id))
Planning:
  Buffers: shared hit=8
Planning Time: 0.147 ms
Execution Time: 0.047 ms
```

`Index Scan using produto_cod_barras_key` (a restrição `UNIQUE` já cria o índice): 0,047 ms, 4 buffers. **Volume real** (120 produtos):

```text
Hash Join  (cost=4.51..14.37 rows=1 width=65) (actual time=0.023..0.024 rows=1 loops=1)
  Hash Cond: (m.id = p.id_marca)
  Buffers: shared hit=4
  ->  Seq Scan on marca m  (cost=0.00..1.92 rows=92 width=18) (actual time=0.001..0.004 rows=92 loops=1)
        Buffers: shared hit=1
  ->  Hash  (cost=4.50..4.50 rows=1 width=54) (actual time=0.012..0.012 rows=1 loops=1)
        Buckets: 1024  Batches: 1  Memory Usage: 9kB
        Buffers: shared hit=3
        ->  Seq Scan on produto p  (cost=0.00..4.50 rows=1 width=54) (actual time=0.002..0.011 rows=1 loops=1)
              Filter: ((cod_barras)::text = '2031271298436'::text)
              Rows Removed by Filter: 119
              Buffers: shared hit=3
  SubPlan 1
    ->  Seq Scan on empresa_produto ep  (cost=0.00..30.75 rows=4 width=0) (actual time=0.000..0.000 rows=0 loops=1)
          Filter: ((NOT ativo) AND (id_produto = p.id))
Planning:
  Buffers: shared hit=15
Planning Time: 0.118 ms
Execution Time: 0.032 ms
```

Com 120 linhas o planner escolhe `Seq Scan` (0,032 ms): é o certo nesse tamanho. Nenhum índice novo.

### 4.2 Busca por nome (`ILIKE '%...%'`)

```sql
SELECT id, nome FROM produto WHERE nome ILIKE '%temp 12345%';
```

**Antes** — sem índice (30.120 produtos):

```text
Seq Scan on produto  (cost=0.00..659.50 rows=3 width=22) (actual time=4.770..11.514 rows=1 loops=1)
  Filter: ((nome)::text ~~* '%temp 12345%'::text)
  Rows Removed by Filter: 30119
  Buffers: shared hit=283
Planning Time: 0.077 ms
Execution Time: 11.519 ms
```

**Depois** — com `CREATE INDEX idx_produto_nome_trgm ON produto USING gin (nome gin_trgm_ops)`, depois de `CREATE EXTENSION pg_trgm` (somente local):

```text
Bitmap Heap Scan on produto  (cost=73.60..84.71 rows=3 width=22) (actual time=0.289..0.290 rows=1 loops=1)
  Recheck Cond: ((nome)::text ~~* '%temp 12345%'::text)
  Heap Blocks: exact=1
  Buffers: shared hit=46
  ->  Bitmap Index Scan on idx_produto_nome_trgm  (cost=0.00..73.60 rows=3 width=0) (actual time=0.285..0.285 rows=1 loops=1)
        Index Cond: ((nome)::text ~~* '%temp 12345%'::text)
        Buffers: shared hit=45
Planning:
  Buffers: shared hit=1
Planning Time: 0.092 ms
Execution Time: 0.298 ms
```

**Conclusão**: um `btree` não atende `ILIKE '%x%'` (padrão com curinga no início); o índice GIN com trigramas atende. `Seq Scan` (283 buffers, 11,5 ms) → `Bitmap Index Scan` (46 buffers, 0,30 ms), ~39×. **Não foi aplicado**: exige a extensão `pg_trgm`, não há consulta por nome neste repositório e, com 120 produtos, não faria diferença.

---

## Índices: o que está no repositório e o que foi só testado

| Índice | Situação | Efeito medido |
|---|---|---|
| `idx_fds_id_produto`, `idx_fds_produto_ativo`, `idx_fds_composto_id_fds` | no `setup_data` | consulta principal de `fn_match_produtos`: 33,9 → 0,30 ms |
| `idx_sessao_acesso_ocorreu_em` | no `setup_data` | DAU por intervalo: 4,66 → 0,67 ms |
| `idx_sessao_acesso_id_usuario` | no `setup_data` | sustenta a reescrita de `vw_sequencia_uso`: 622,7 → 0,64 ms |
| `produto_cod_barras_key` (`UNIQUE`) | no DDL | scan por código de barras: `Index Scan` em 0,047 ms |
| `idx_historico_recomendacao_usuario_data` | **só testado** (local, transação com rollback) | histórico por usuário: 5,64 → 0,023 ms |
| `idx_produto_nome_trgm` (GIN) | **só testado** (local, transação com rollback) | busca por nome: 11,5 → 0,30 ms |

Nesta etapa nenhum índice foi criado, removido ou alterado no repositório nem na Aiven.
