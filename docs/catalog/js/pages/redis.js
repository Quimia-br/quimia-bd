/* Redis no quimia-api: cache de leitura sobre o PostgreSQL. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone } = Q.util;
  const { cabecalho } = Q.ui;

  // Nomes e TTLs de CacheDoCatalogo, CacheDaSeguranca, CacheDosPontos,
  // CacheDosInsights e application.yml do quimia-api.
  const CACHES = [
    { nome: 'produto', grupo: 'Catálogo', ttl: '1 h', valor: 'ProdutoView', leitura: 'GET /produtos/{id}', saida: 'Cadastro, alteração ou remoção de produto no portal' },
    { nome: 'produto-por-codigo', grupo: 'Catálogo', ttl: '1 h', valor: 'ProdutoView', leitura: 'POST /produtos/busca-por-codigo-barras', saida: 'Cadastro, alteração ou remoção de produto no portal' },
    { nome: 'busca-de-produtos', grupo: 'Catálogo', ttl: '10 min', valor: 'Pagina<ProdutoView>', leitura: 'GET /produtos (filtros e paginação)', saida: 'Cadastro, alteração ou remoção de produto no portal' },
    { nome: 'substancia', grupo: 'Segurança', ttl: '24 h', valor: 'SubstanciaView', leitura: 'GET /substancias/{id}', saida: 'TTL; resultados inexistentes não são guardados' },
    { nome: 'composicao', grupo: 'Segurança', ttl: '1 h', valor: 'List<ComposicaoView>', leitura: 'GET /produtos/{id}/substancias', saida: 'FDS nova do produto, após o commit' },
    { nome: 'resumo-da-fds', grupo: 'Segurança', ttl: '1 h', valor: 'ResumoSimplificadoView', leitura: 'GET /estante/produtos/{id}/resumo-simplificado', saida: 'FDS nova do produto, após o commit' },
    { nome: 'primeiros-socorros', grupo: 'Segurança', ttl: '1 h', valor: 'PrimeirosSocorrosView', leitura: 'GET /estante/produtos/{id}/primeiros-socorros', saida: 'FDS nova do produto, após o commit' },
    { nome: 'pontos', grupo: 'Pontos', ttl: '6 h', valor: 'List<PontoView>', leitura: 'GET /pontos (tipo, UF e bairro)', saida: 'TTL; a API não grava pontos' },
    { nome: 'resumo-da-empresa', grupo: 'Insights', ttl: '5 min', valor: 'ResumoEmpresaView', leitura: 'GET /empresas/me/resumo e /estatisticas', saida: 'TTL' }
  ];

  function abas(ativa) {
    return `<nav class="abas" aria-label="Visualização"><a class="aba${ativa === 'banco' ? ' ativa' : ''}" href="#/banco-redis">${icone('table')}Lista</a><a class="aba${ativa === 'modelagem' ? ' ativa' : ''}" href="#/modelagem-redis">${icone('network')}Modelagem</a></nav>`;
  }

  function bancoRedis() {
    return `${cabecalho({ secao: 'Explorador', titulo: 'Banco de Dados', subtitulo: 'Redis · cache de leitura do quimia-api sobre o PostgreSQL.' })}
      ${abas('banco')}
      <div class="barra-filtros">${Q.ui.seletorBancos('banco', 'Redis')}</div>
      <section class="cartao"><div class="cartao-topo"><h2>Redis no Quimia</h2><span class="neo4j-card-icone"><img src="icons/redis_logo.svg" alt=""></span></div>
        <p>O <code>quimia-api</code> usa Redis como cache das leituras repetidas. A API consulta o cache antes do PostgreSQL; em uma falta, lê do banco e guarda o resultado pelo prazo definido para aquela chave. O PostgreSQL continua sendo a fonte dos dados.</p>
        <p class="legenda">O cache é opcional e fica desligado por padrão. Com <code>QUIMIA_CACHE_ENABLED=false</code>, a API lê diretamente do PostgreSQL e não contata o Redis.</p>
      </section>
      <div class="grade-2">
        <a class="cartao neo4j-card" href="#/redis-fluxo"><span class="neo4j-card-icone"><img src="icons/audio-waveform.svg" alt=""></span><h2>Fluxo do cache</h2><p class="sutil">Acerto, falta, invalidação após escrita e comportamento quando o Redis falha.</p><span class="botao">Entender o fluxo</span></a>
        <a class="cartao neo4j-card" href="#/redis-caches"><span class="neo4j-card-icone">${icone('database')}</span><h2>Caches e validade</h2><p class="sutil">Nove caches distribuídos entre catálogo, segurança, pontos e insights.</p><span class="botao">Ver os caches</span></a>
      </div>
      <section class="cartao"><h2>Onde o cache ajuda</h2>
        <div class="grade-2 redis-dominios">
          <div><h3>Catálogo</h3><p>Detalhe do produto, código de barras e busca paginada.</p></div>
          <div><h3>Segurança</h3><p>Substâncias, composição, resumo da FDS e primeiros socorros.</p></div>
          <div><h3>Pontos</h3><p>Pontos de descarte por tipo, estado e bairro.</p></div>
          <div><h3>Insights</h3><p>Agregados do painel da empresa por cinco minutos.</p></div>
        </div>
      </section>`;
  }

  function modelagemRedis() {
    const colunas = 'minmax(0,1.3fr) minmax(0,1.5fr) minmax(80px,.5fr)';
    return `${cabecalho({ secao: 'Explorador', titulo: 'Modelagem', subtitulo: 'Redis · chaves, valores JSON e validade dos caches da API.' })}
      ${abas('modelagem')}
      <div class="barra-filtros">${Q.ui.seletorBancos('modelagem', 'Redis')}</div>
      <section class="cartao"><h2>Modelo das entradas</h2>
        <div class="redis-modelo" aria-label="Estrutura de uma entrada no Redis">
          <div><span>Chave</span><code>{prefixo}{nome-do-cache}::{chave-da-consulta}</code></div>
          <div><span>Valor</span><code>JSON do tipo registrado pelo módulo</code></div>
          <div><span>Validade</span><code>TTL próprio de cada cache</code></div>
        </div>
        <p class="legenda">Exemplo de chave: <code>quimia:produto::123</code>. O prefixo padrão <code>quimia:</code> pode ser alterado por <code>QUIMIA_CACHE_PREFIX</code> para separar ambientes. O valor é serializado como JSON do tipo esperado, sem nome de classe no Redis; valores nulos não são guardados.</p>
      </section>
      <section class="cartao"><h2>Caches registrados</h2>
        <div class="lista"><div class="lista-cabecalho" style="--colunas:${colunas}"><span>Nome do cache</span><span>Valor JSON</span><span>TTL</span></div>
          ${CACHES.map((cache) => `<div class="linha" style="--colunas:${colunas}"><code>${esc(cache.nome)}</code><span data-rotulo="Valor JSON"><code>${esc(cache.valor)}</code></span><span data-rotulo="TTL">${esc(cache.ttl)}</span></div>`).join('')}
        </div>
        <p class="legenda">Cada módulo registra nome, TTL e tipo do valor em <code>internal/config/</code>. A configuração geral impede a criação de um cache com nome não registrado.</p>
      </section>`;
  }

  function fluxoRedis() {
    return `${cabecalho({ secao: 'Redis', titulo: 'Fluxo do cache', subtitulo: 'Como o quimia-api atende uma leitura e atualiza o cache.' })}
      <section class="cartao"><h2>Exemplo: consultar um produto</h2>
        <ol class="redis-etapas">
          <li><strong>Pedido</strong><span>O app chama <code>GET /api/v1/produtos/{id}</code>; a API procura a chave no Redis.</span></li>
          <li><strong>Acerto</strong><span>Se a chave existe, devolve o <code>ProdutoView</code> do Redis sem abrir conexão com o PostgreSQL.</span></li>
          <li><strong>Falta</strong><span>Se a chave não existe, consulta o PostgreSQL, grava o resultado no Redis com TTL de 1 hora e responde.</span></li>
          <li><strong>Escrita</strong><span>Cadastro, alteração ou remoção de produto no portal limpam os três caches do catálogo. A leitura seguinte busca o dado atualizado no PostgreSQL.</span></li>
        </ol>
        <p class="legenda">O cache envolve a transação: a limpeza associada à escrita ocorre após o commit. Uma leitura concorrente ainda pode recolocar um valor antigo; o TTL limita esse atraso.</p>
      </section>
      <div class="grade-2">
        <section class="cartao"><h2>Redis indisponível ou lento</h2><p>Uma falha de leitura faz a API consultar o PostgreSQL e registrar o problema no log. O prazo padrão de conexão e operação é 500 ms, configurável por <code>QUIMIA_CACHE_TIMEOUT_MS</code>.</p><p class="legenda">Se a limpeza falhar, o dado antigo pode permanecer até o TTL; a falha é registrada como erro.</p></section>
        <section class="cartao"><h2>Ativação</h2><p>O cache só é usado com <code>QUIMIA_CACHE_ENABLED=true</code>. <code>REDIS_URL</code> aponta para o serviço Redis; no Aiven, a URI usa <code>rediss://</code> para TLS.</p><p class="legenda">As configurações gerais ficam em <code>CacheConfig.java</code>. O prefixo padrão das chaves é <code>quimia:</code>.</p></section>
      </div>
      <section class="cartao"><h2>Fonte</h2><p>Implementação no repositório <code>quimia-api</code>, introduzida no <a href="https://github.com/Quimia-br/quimia-api/pull/28" target="_blank" rel="noopener noreferrer">PR #28</a>.</p></section>`;
  }

  function cachesRedis() {
    const colunas = 'minmax(0,1fr) minmax(0,1.5fr) minmax(0,1.8fr)';
    return `${cabecalho({ secao: 'Redis', titulo: 'Caches e validade', subtitulo: 'Leituras armazenadas, TTLs e momentos de invalidação.' })}
      <section class="cartao"><h2>O que entra no Redis</h2><p>Cada chave representa uma consulta específica. As entradas expiram pelo TTL e algumas são apagadas antes quando a API grava um novo produto ou recebe uma nova FDS.</p></section>
      ${['Catálogo', 'Segurança', 'Pontos', 'Insights'].map((grupo) => `<section class="cartao"><h2>${grupo}</h2>
        <div class="lista"><div class="lista-cabecalho" style="--colunas:${colunas}"><span>Cache · TTL</span><span>Leitura</span><span>Quando sai do cache</span></div>
          ${CACHES.filter((cache) => cache.grupo === grupo).map((cache) => `<div class="linha" style="--colunas:${colunas}"><span><code>${esc(cache.nome)}</code><br><span class="sutil">${esc(cache.ttl)}</span></span><span data-rotulo="Leitura"><code>${esc(cache.leitura)}</code></span><span data-rotulo="Quando sai">${esc(cache.saida)}</span></div>`).join('')}
        </div></section>`).join('')}
      <section class="cartao"><h2>Regras de atualização</h2><p>Uma FDS nova limpa, após o commit, composição, resumo e primeiros socorros do produto. Substâncias e pontos podem ser alterados diretamente no banco pelo DBA; essas entradas são atualizadas quando o TTL vence. A ordenação dos pontos pelo CEP informado é feita em memória, após a leitura do cache.</p><p class="legenda">A empresa ativa é conferida a cada pedido do painel, fora do cache. Regras de incompatibilidade não entram no Redis.</p></section>`;
  }

  Q.paginas.registrar('banco-redis', { render: bancoRedis, titulo: 'Redis · Banco de Dados', secaoNav: () => 'banco' });
  Q.paginas.registrar('modelagem-redis', { render: modelagemRedis, titulo: 'Redis · Modelagem', secaoNav: () => 'modelagem' });
  Q.paginas.registrar('redis-fluxo', { render: fluxoRedis, titulo: 'Redis · Fluxo do cache' });
  Q.paginas.registrar('redis-caches', { render: cachesRedis, titulo: 'Redis · Caches e validade' });
})(window.Quimia);
