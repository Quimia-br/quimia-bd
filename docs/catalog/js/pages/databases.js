/* Complemento do catálogo: navegação entre bancos e documentação do grafo Neo4j. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone } = Q.util;
  const { cabecalho, blocoCodigo } = Q.ui;
  let zoomNeo4j = 1;

  const CRIACAO = `// Exemplo fictício e independente dos dados do PostgreSQL.
MERGE (p1:Produto:CatalogoDemo {id: 'produto-1'})
SET p1.nome = 'Produto fictício A'
MERGE (p2:Produto:CatalogoDemo {id: 'produto-2'})
SET p2.nome = 'Produto fictício B'
MERGE (f1:FDS:CatalogoDemo {id: 'fds-1'})
SET f1.versao = '1.0'
MERGE (f2:FDS:CatalogoDemo {id: 'fds-2'})
SET f2.versao = '1.0'
MERGE (s:Substancia:CatalogoDemo {id: 'substancia-1'})
SET s.nome = 'Substância fictícia X'
MERGE (p1)-[:TEM_FDS]->(f1)
MERGE (p2)-[:TEM_FDS]->(f2)
MERGE (f1)-[:CONTEM_SUBSTANCIA]->(s)
MERGE (f2)-[:CONTEM_SUBSTANCIA]->(s)
RETURN p1, p2, f1, f2, s;`;

  const NEGOCIO = `// Pergunta: quais produtos compartilham uma substância nas suas FDS?
MATCH caminho =
  (p1:Produto:CatalogoDemo)-[:TEM_FDS]->(:FDS:CatalogoDemo)
  -[:CONTEM_SUBSTANCIA]->(s:Substancia:CatalogoDemo)
  <-[:CONTEM_SUBSTANCIA]-(:FDS:CatalogoDemo)
  <-[:TEM_FDS]-(p2:Produto:CatalogoDemo)
WHERE p1.id < p2.id
RETURN p1.nome AS produto_1,
       p2.nome AS produto_2,
       s.nome AS substancia_em_comum,
       caminho;`;

  const BANCOS = [
    { nome: 'PostgreSQL', logo: 'postgrees_logo.svg', paginas: { banco: '#/banco', modelagem: '#/modelagem' } },
    { nome: 'Neo4j', logo: 'neo4j_logo.svg', paginas: { banco: '#/banco-neo4j', modelagem: '#/modelagem-neo4j' } },
    { nome: 'MongoDB', logo: 'mongo_logo.svg' },
    { nome: 'Redis', logo: 'redis_logo.svg' }
  ];

  function seletorBancos(pagina, ativo) {
    return `<div class="bancos-seletor" role="group" aria-label="Selecionar banco de dados">${BANCOS.map((banco) => {
      const classe = `banco-opcao${ativo === banco.nome ? ' ativa' : ''}`;
      const conteudo = `<img src="icons/${banco.logo}" alt="" aria-hidden="true">`;
      return banco.paginas
        ? `<a class="${classe}" href="${banco.paginas[pagina]}" title="${banco.nome}" aria-label="${banco.nome}"${ativo === banco.nome ? ' aria-current="page"' : ''}>${conteudo}</a>`
        : `<button class="${classe}" type="button" title="${banco.nome}: em breve" aria-label="${banco.nome}: em breve" disabled>${conteudo}</button>`;
    }).join('')}</div>`;
  }

  function abas(ativa) {
    return `<nav class="abas" aria-label="Visualização"><a class="aba${ativa === 'banco' ? ' ativa' : ''}" href="#/banco-neo4j">${Q.util.icone('table')}Lista</a><a class="aba${ativa === 'modelagem' ? ' ativa' : ''}" href="#/modelagem-neo4j">${Q.util.icone('network')}Modelagem</a></nav>`;
  }

  function card(titulo, texto, imagem, rota) {
    return `<a class="cartao neo4j-card" href="#/${rota}"><span class="neo4j-card-icone"><img src="icons/${imagem}" alt=""></span><h2>${esc(titulo)}</h2><p class="sutil">${esc(texto)}</p><span class="botao">Ver query</span></a>`;
  }

  function banco() {
    return `${cabecalho({ secao: 'Explorador', titulo: 'Banco de Dados', subtitulo: 'Neo4j · grafo demonstrativo de Produto, FDS e Substância.' })}
      ${abas('banco')}
      <div class="barra-filtros">${seletorBancos('banco', 'Neo4j')}</div>
      <p class="legenda">As queries abaixo usam apenas registros fictícios. O catálogo não executa comandos no Aura; copie a query para o editor do Neo4j.</p>
      <div class="grade-2">
        ${card('Grafo', 'Criação dos nós e das relações do exemplo.', 'share-2.svg', 'neo4j-grafo')}
        ${card('Negócio', '“Quais produtos compartilham uma substância nas suas FDS?”', 'building-2.svg', 'neo4j-negocio')}
      </div>`;
  }

  function modelagem() {
    return `${cabecalho({ secao: 'Explorador', titulo: 'Modelagem', subtitulo: 'Neo4j · entidades principais e relações do grafo demonstrativo.' })}
      ${abas('modelagem')}
      <div class="barra-filtros">${seletorBancos('modelagem', 'Neo4j')}</div>
      <section class="cartao"><div class="cartao-topo"><h2>Modelo do grafo</h2>
        <div class="diagrama-controles">
          <button class="botao-icone pequeno fundo" data-acao="neo4j-zoom-menos" aria-label="Diminuir zoom">${icone('minus')}</button>
          <button class="botao" data-acao="neo4j-zoom-ajustar">${icone('rotate-ccw')}Ajustar</button>
          <button class="botao-icone pequeno fundo" data-acao="neo4j-zoom-mais" aria-label="Aumentar zoom">${icone('plus')}</button>
          <a class="botao" href="#/neo4j-grafo">Ver query</a>
        </div></div>
        <div class="neo4j-modelo"><img src="icons/visualisation.png" alt="Visualização do Neo4j Aura: produto-1 e produto-2 têm FDS próprias; as duas FDS contêm a mesma substância."></div>
        <p class="legenda">Um produto tem uma FDS; uma FDS pode conter várias substâncias; a mesma substância pode constar em FDS de produtos diferentes.</p>
      </section>`;
  }

  function aplicarZoomNeo4j() {
    const palco = document.querySelector('.neo4j-modelo');
    const imagem = palco?.querySelector('img');
    if (!imagem) return;
    imagem.style.width = `${Math.round(Math.min(932, palco.clientWidth) * zoomNeo4j)}px`;
    palco.scrollLeft = Math.max(0, (imagem.offsetWidth - palco.clientWidth) / 2);
    palco.scrollTop = Math.max(0, (imagem.offsetHeight - palco.clientHeight) / 2);
  }

  document.addEventListener('click', (evento) => {
    const acao = evento.target.closest('[data-acao]')?.dataset.acao;
    if (acao === 'neo4j-zoom-mais') zoomNeo4j = Math.min(2.5, zoomNeo4j * 1.25);
    else if (acao === 'neo4j-zoom-menos') zoomNeo4j = Math.max(0.5, zoomNeo4j / 1.25);
    else if (acao === 'neo4j-zoom-ajustar') zoomNeo4j = 1;
    else return;
    aplicarZoomNeo4j();
  });

  window.addEventListener('resize', () => {
    if (Q.rotaAtual?.().pagina === 'modelagem-neo4j') aplicarZoomNeo4j();
  });

  function detalhe(tipo) {
    const grafo = tipo === 'grafo';
    const titulo = grafo ? 'Grafo' : 'Negócio';
    const texto = grafo
      ? 'Crie dois produtos, suas FDS e uma substância compartilhada. MERGE permite executar o exemplo novamente sem duplicar os nós e as relações.'
      : 'O caminho percorre Produto → FDS → Substância ← FDS ← Produto.';
    return `${cabecalho({ secao: 'Neo4j', titulo, subtitulo: esc(texto) })}
      ${grafo ? '' : '<section class="cartao"><h2>Pergunta de negócio</h2><p>“Quais produtos compartilham uma substância nas suas FDS?”</p></section>'}
      <section class="cartao"><div class="cartao-topo"><h2>${grafo ? 'Query de criação' : 'Query de consulta'}</h2></div>
        <p class="legenda">Copie e execute no editor Query do Neo4j Aura.${grafo ? ' Todos os dados deste exemplo são fictícios.' : ' Execute antes a query de criação.'}</p>
        ${blocoCodigo(grafo ? CRIACAO : NEGOCIO, grafo ? 'Cypher · criação do grafo' : 'Cypher · pergunta de negócio')}
      </section>${grafo ? '' : '<section class="cartao"><h2>Resultado esperado</h2><p>Produto fictício A e Produto fictício B compartilham a Substância fictícia X nas suas FDS.</p><p class="legenda">A consulta atravessa quatro relações; a condição p1.id &lt; p2.id evita repetir o mesmo par na ordem inversa.</p></section>'}`;
  }

  Q.ui.seletorBancos = seletorBancos;
  Q.paginas.registrar('banco-neo4j', { render: banco, titulo: 'Neo4j · Banco de Dados', secaoNav: () => 'banco' });
  Q.paginas.registrar('modelagem-neo4j', { render: modelagem, aoRenderizar: aplicarZoomNeo4j, titulo: 'Neo4j · Modelagem', secaoNav: () => 'modelagem' });
  Q.paginas.registrar('neo4j-grafo', { render: () => detalhe('grafo'), titulo: 'Neo4j · Grafo' });
  Q.paginas.registrar('neo4j-negocio', { render: () => detalhe('negocio'), titulo: 'Neo4j · Negócio' });
})(window.Quimia);
