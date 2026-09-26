/* Quimia · páginas de listagem com filtros: Banco de Dados (#/banco) e os tipos
   de objeto (#/views, #/procedures, #/functions, #/indices, #/triggers, #/logs). */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, plural, normalizar } = Q.util;
  const { cabecalho, cardObjeto, cardTabela } = Q.ui;
  const { dados, TIPOS, NIVEIS, DOMINIOS } = Q;

  // Filtros disponíveis: de onde vem o valor, como rotular e ordenar.
  const FILTROS = {
    dominio: { rotulo: 'Domínio', valor: (o) => o.dominio || 'sem domínio', ordem: (v) => DOMINIOS.indexOf(v) },
    nivel: {
      rotulo: 'Acesso', valor: (o) => o.nivel_acesso || 'sem classificação',
      rotuloValor: (v) => NIVEIS[v]?.rotulo ?? v, ordem: (v) => Object.keys(NIVEIS).indexOf(v)
    },
    tipo: { rotulo: 'Tipo', valor: (o) => TIPOS[o.tipo].singular },
    tabela: { rotulo: 'Tabela', valor: (o) => o.tabela },
    categoria: {
      rotulo: 'Categoria',
      valor: (o) => (String(o.retorno).toUpperCase() === 'TRIGGER' ? 'Função de trigger' : 'Função de negócio')
    }
  };

  // Cada listagem: tipos exibidos, filtros oferecidos, agrupamento padrão e textos.
  const LISTAGENS = {
    banco: {
      tipos: ['tabela', 'log'], filtros: ['dominio', 'nivel', 'tipo'], agrupar: 'dominio', card: cardTabela,
      placeholder: 'Filtrar tabelas ou colunas', secao: 'Explorador', titulo: 'Banco de Dados',
      texto: 'Tabelas, tabelas de log, relacionamentos e estrutura física do banco.'
    },
    views: {
      tipos: ['view'], filtros: ['dominio', 'nivel'], agrupar: 'dominio', placeholder: 'Filtrar views ou colunas',
      texto: 'Dimensões e fatos do Data Mart, lidos pelo Databricks.'
    },
    procedures: {
      tipos: ['procedure'], filtros: [], agrupar: '', placeholder: 'Filtrar procedures',
      texto: 'Rotinas que executam operações completas numa transação.'
    },
    functions: {
      tipos: ['funcao'], filtros: ['categoria'], agrupar: 'categoria', placeholder: 'Filtrar functions',
      texto: 'Funções de negócio e funções usadas pelas triggers.'
    },
    indices: {
      tipos: ['indice'], filtros: ['tabela'], agrupar: 'tabela', placeholder: 'Filtrar índices ou colunas',
      texto: 'Índices criados a partir das consultas analisadas com EXPLAIN ANALYZE.'
    },
    triggers: {
      tipos: ['trigger'], filtros: ['tabela'], agrupar: 'tabela', placeholder: 'Filtrar triggers',
      texto: 'Gatilhos de auditoria, sessão e processamento de FDS.'
    },
    logs: {
      tipos: ['log'], filtros: ['nivel'], agrupar: '', placeholder: 'Filtrar tabelas de log ou colunas',
      texto: 'Tabelas de log documentadas em src/database/sql/logs.'
    }
  };

  // Estado dos filtros por página; continua valendo ao sair e voltar.
  const estado = {};

  function textoFiltro(o) {
    const colunas = (o.colunas ?? []).map((c) => `${c.nome} ${c.descricao ?? ''}`).join(' ');
    return normalizar([o.nome, o.descricao, o.dominio, o.tabela, o.funcao, o.argumentos, o.retorno,
      (o.colunas_indice ?? []).join(' '), colunas].filter(Boolean).join(' '));
  }
  const indiceFiltro = new Map(dados.objetos.map((o) => [o.nome, textoFiltro(o)]));

  function filtrosDa(rota) {
    if (!estado[rota]) {
      const config = LISTAGENS[rota];
      estado[rota] = { termo: '', agrupar: config.agrupar, ...Object.fromEntries(config.filtros.map((f) => [f, ''])) };
    }
    return estado[rota];
  }

  const rotuloValor = (filtro, valor) => (FILTROS[filtro].rotuloValor ? FILTROS[filtro].rotuloValor(valor) : valor);

  function ordenarValores(filtro, valores) {
    const ordem = FILTROS[filtro].ordem;
    return [...valores].sort((a, b) => (ordem ? ordem(a) - ordem(b) : 0) || a.localeCompare(b));
  }

  const objetosDa = (rota) => dados.objetos.filter((o) => LISTAGENS[rota].tipos.includes(o.tipo));

  function filtrar(rota) {
    const config = LISTAGENS[rota];
    const filtros = filtrosDa(rota);
    const termo = normalizar(filtros.termo.trim());
    return objetosDa(rota)
      .filter((o) => !termo || indiceFiltro.get(o.nome).includes(termo))
      .filter((o) => config.filtros.every((f) => !filtros[f] || FILTROS[f].valor(o) === filtros[f]))
      .sort((a, b) => a.nome.localeCompare(b.nome));
  }

  function barraFiltros(rota) {
    const config = LISTAGENS[rota];
    const filtros = filtrosDa(rota);
    const todos = objetosDa(rota);
    const seletores = config.filtros.map((f) => {
      const valores = ordenarValores(f, new Set(todos.map(FILTROS[f].valor)));
      return `<label class="seletor"><span>${esc(FILTROS[f].rotulo)}</span>
        <select data-filtro-campo="${f}"><option value="">Todos</option>${valores.map((v) =>
          `<option value="${esc(v)}"${filtros[f] === v ? ' selected' : ''}>${esc(rotuloValor(f, v))}</option>`).join('')}</select></label>`;
    }).join('');
    const agrupar = config.filtros.length ? `<label class="seletor"><span>Agrupar por</span>
        <select data-filtro-campo="agrupar"><option value="">Nada</option>${config.filtros.map((f) =>
          `<option value="${f}"${filtros.agrupar === f ? ' selected' : ''}>${esc(FILTROS[f].rotulo)}</option>`).join('')}</select></label>` : '';
    return `<div class="barra-filtros" role="search" aria-label="Filtrar ${esc(rota)}">
        <label class="busca busca-local">${icone('search')}
          <input type="search" data-filtro-campo="termo" value="${esc(filtros.termo)}" placeholder="${esc(config.placeholder)}" aria-label="${esc(config.placeholder)}" autocomplete="off"></label>
        ${seletores}${agrupar}
        <button class="botao" data-acao="limpar-filtros">Limpar filtros</button>
      </div>`;
  }

  function resultado(rota) {
    const config = LISTAGENS[rota];
    const filtros = filtrosDa(rota);
    const itens = filtrar(rota);
    const total = objetosDa(rota).length;
    const card = config.card ?? cardObjeto;
    const contador = `<p class="contador" aria-live="polite">${itens.length === total
      ? plural(total, 'objeto', 'objetos') : `${itens.length} de ${plural(total, 'objeto', 'objetos')}`}</p>`;
    if (!itens.length) return `${contador}<p class="vazio">Nenhum objeto com esses filtros. <button class="botao" data-acao="limpar-filtros">Limpar filtros</button></p>`;
    if (!filtros.agrupar) return `${contador}<div class="grade-cards">${itens.map(card).join('')}</div>`;

    const grupos = new Map();
    for (const o of itens) {
      const chave = FILTROS[filtros.agrupar].valor(o);
      if (!grupos.has(chave)) grupos.set(chave, []);
      grupos.get(chave).push(o);
    }
    return contador + ordenarValores(filtros.agrupar, grupos.keys()).map((chave) => `<section class="grupo">
        <h2 class="grupo-titulo">${esc(rotuloValor(filtros.agrupar, chave))}<span class="nav-contagem">${grupos.get(chave).length}</span></h2>
        <div class="grade-cards">${grupos.get(chave).map(card).join('')}</div></section>`).join('');
  }

  // Abas Lista/Modelagem, compartilhadas com a página de Modelagem.
  function abasBanco(ativa) {
    return `<nav class="abas" aria-label="Visualização">
      <a class="aba${ativa === 'lista' ? ' ativa' : ''}" href="#/banco">${icone('table')}Lista</a>
      <a class="aba${ativa === 'modelagem' ? ' ativa' : ''}" href="#/modelagem">${icone('network')}Modelagem</a></nav>`;
  }

  function pagina(rota) {
    const config = LISTAGENS[rota];
    const tipo = config.tipos[0];
    return `${cabecalho({ secao: config.secao ?? 'Objetos', titulo: config.titulo ?? TIPOS[tipo].rotulo, subtitulo: esc(config.texto) })}
      ${rota === 'banco' ? abasBanco('lista') : ''}
      ${barraFiltros(rota)}
      <div class="listagem" id="listagem">${resultado(rota)}</div>`;
  }

  for (const rota of Object.keys(LISTAGENS)) {
    Q.paginas.registrar(rota, {
      render: () => pagina(rota),
      titulo: LISTAGENS[rota].titulo ?? TIPOS[LISTAGENS[rota].tipos[0]].rotulo
    });
  }

  // Ao filtrar, só a lista é redesenhada, para o campo não perder o foco.
  document.addEventListener('input', (evento) => {
    const campo = evento.target.dataset?.filtroCampo;
    const rota = Q.rotaAtual?.().pagina;
    if (!campo || !LISTAGENS[rota]) return;
    filtrosDa(rota)[campo] = evento.target.value;
    const alvo = document.getElementById('listagem');
    if (alvo) alvo.innerHTML = resultado(rota);
  });

  document.addEventListener('click', (evento) => {
    if (!evento.target.closest('[data-acao="limpar-filtros"]')) return;
    const rota = Q.rotaAtual().pagina;
    if (!LISTAGENS[rota]) return;
    delete estado[rota];
    const rolagem = window.scrollY;
    Q.render();
    window.scrollTo(0, rolagem);
  });

  Q.ui.abasBanco = abasBanco;
})(window.Quimia);
