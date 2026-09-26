/* Quimia · ferramenta Dependências (#/dependencias[/<objeto>]): mapa em camadas desenhado em SVG. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc } = Q.util;
  const { cabecalho, resumoNumeros } = Q.ui;
  const { dados, porNome, TIPOS } = Q;

  const estado = { foco: '', direcao: 'ambos', ocultos: new Set() };
  // Medidas do desenho, em px.
  const LARG = 220; const ALT = 48; const COL = 300; const LIN = 62; const MARGEM = 24;

  // Nível = maior distância até um objeto que não depende de nada (o grafo não tem ciclos).
  function niveis() {
    const nivel = new Map();
    const calcular = (nome, visitando = new Set()) => {
      if (nivel.has(nome)) return nivel.get(nome);
      if (visitando.has(nome)) return 0;
      visitando.add(nome);
      const deps = porNome.get(nome)?.dependencias ?? [];
      const valor = deps.length ? 1 + Math.max(...deps.map((d) => calcular(d, visitando))) : 0;
      nivel.set(nome, valor);
      return valor;
    };
    dados.objetos.forEach((o) => calcular(o.nome));
    return nivel;
  }

  function cadeia(nome, direcao) {
    const achados = new Set([nome]);
    const andar = (atual, campo) => {
      for (const proximo of porNome.get(atual)?.[campo] ?? []) {
        if (!achados.has(proximo)) { achados.add(proximo); andar(proximo, campo); }
      }
    };
    if (direcao !== 'dependentes') andar(nome, 'dependencias');
    if (direcao !== 'dependencias') andar(nome, 'usado_por');
    return achados;
  }

  function visiveis() {
    const base = estado.foco ? cadeia(estado.foco, estado.direcao) : new Set(dados.objetos.map((o) => o.nome));
    return new Set([...base].filter((n) => !estado.ocultos.has(porNome.get(n)?.tipo) || n === estado.foco));
  }

  function desenhar() {
    const alvo = document.getElementById('grafo');
    if (!alvo) return;
    const mostrar = visiveis();
    const nivel = niveis();

    // Colunas por nível, sem colunas vazias.
    const niveisUsados = [...new Set([...mostrar].map((n) => nivel.get(n)))].sort((a, b) => a - b);
    const coluna = new Map(niveisUsados.map((n, i) => [n, i]));
    const colunas = niveisUsados.map(() => []);
    const ordemTipo = Object.keys(TIPOS);
    [...mostrar].sort((a, b) => ordemTipo.indexOf(porNome.get(a).tipo) - ordemTipo.indexOf(porNome.get(b).tipo) || a.localeCompare(b))
      .forEach((n) => colunas[coluna.get(nivel.get(n))].push(n));

    // Ordena cada coluna pela altura média do que o objeto usa (menos cruzamentos).
    const posicao = new Map();
    colunas.forEach((lista, c) => {
      if (c > 0) {
        const media = (n) => {
          const ys = porNome.get(n).dependencias.filter((d) => posicao.has(d)).map((d) => posicao.get(d));
          return ys.length ? ys.reduce((s, y) => s + y, 0) / ys.length : Infinity;
        };
        lista.sort((a, b) => media(a) - media(b));
      }
      lista.forEach((n, i) => posicao.set(n, i));
    });

    const coords = new Map();
    colunas.forEach((lista, c) => lista.forEach((n, i) => coords.set(n, { x: MARGEM + c * COL, y: MARGEM + i * LIN })));
    const largura = MARGEM * 2 + (colunas.length - 1) * COL + LARG;
    const altura = MARGEM * 2 + Math.max(...colunas.map((l) => l.length), 1) * LIN - (LIN - ALT);

    const arestas = [];
    for (const n of mostrar) {
      for (const dep of porNome.get(n).dependencias) {
        if (!mostrar.has(dep)) continue;
        const a = coords.get(dep); const b = coords.get(n);
        const x1 = a.x + LARG; const y1 = a.y + ALT / 2; const x2 = b.x - 6; const y2 = b.y + ALT / 2;
        const curva = Math.max(40, (x2 - x1) / 2);
        arestas.push(`<path class="aresta" data-de="${esc(dep)}" data-para="${esc(n)}" d="M${x1},${y1} C${x1 + curva},${y1} ${x2 - curva},${y2} ${x2},${y2}" marker-end="url(#seta)"/>`);
      }
    }
    const nos = [...mostrar].map((n) => {
      const o = porNome.get(n); const { x, y } = coords.get(n);
      const rotulo = n.length > 26 ? `${n.slice(0, 25)}…` : n;
      return `<a href="#/objeto/${encodeURIComponent(n)}" class="no${n === estado.foco ? ' foco' : ''}" data-no="${esc(n)}">
        <title>${esc(n)} · ${esc(TIPOS[o.tipo].singular)}</title>
        <rect x="${x}" y="${y}" width="${LARG}" height="${ALT}" rx="12"/>
        <rect x="${x}" y="${y}" width="6" height="${ALT}" rx="3" style="fill:${TIPOS[o.tipo].cor}"/>
        <text x="${x + 18}" y="${y + 20}" class="no-nome">${esc(rotulo)}</text>
        <text x="${x + 18}" y="${y + 37}" class="no-tipo">${esc(TIPOS[o.tipo].singular)}</text></a>`;
    }).join('');

    alvo.innerHTML = mostrar.size ? `<svg class="grafo-svg" width="${largura}" height="${altura}" viewBox="0 0 ${largura} ${altura}" role="img"
        aria-label="Mapa de dependências com ${mostrar.size} objetos">
        <defs><marker id="seta" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
          <path d="M0,0 L10,5 L0,10 z" class="seta"/></marker></defs>
        <g>${arestas.join('')}</g><g>${nos}</g></svg>` : '<p class="vazio">Nenhum objeto com esses filtros.</p>';
    const contador = document.getElementById('grafo-contador');
    if (contador) contador.textContent = `${mostrar.size} objetos · ${arestas.length} relações`;
  }

  function render(parametro) {
    if (parametro && porNome.has(parametro)) estado.foco = parametro;
    const nivel = niveis();
    const relacoes = dados.objetos.reduce((s, o) => s + o.dependencias.length, 0);
    const externas = dados.avisos.filter((a) => a.includes('não está definido nos .sql')).length;
    const opcoes = Object.entries(TIPOS).map(([tipo, info]) => {
      const itens = dados.objetos.filter((o) => o.tipo === tipo);
      return itens.length ? `<optgroup label="${esc(info.rotulo)}">${itens.map((o) =>
        `<option value="${esc(o.nome)}"${o.nome === estado.foco ? ' selected' : ''}>${esc(o.nome)}</option>`).join('')}</optgroup>` : '';
    }).join('');
    const legenda = Object.entries(TIPOS).filter(([t]) => dados.objetos.some((o) => o.tipo === t)).map(([tipo, info]) =>
      `<button class="legenda-tipo" data-dep-tipo="${tipo}" aria-pressed="${!estado.ocultos.has(tipo)}">
        <span class="ponto" style="--cor:${info.cor}"></span>${esc(info.rotulo)}</button>`).join('');
    const opcaoDirecao = (valor, rotulo) => `<option value="${valor}"${estado.direcao === valor ? ' selected' : ''}>${rotulo}</option>`;

    return `${cabecalho({ secao: 'Ferramentas', titulo: 'Dependências', subtitulo: 'Como cada objeto alimenta os próximos níveis do banco. A seta parte do objeto base e aponta para quem o usa.' })}
      ${resumoNumeros([[dados.objetos.length, 'objetos'], [relacoes, 'relações resolvidas'],
        [Math.max(...nivel.values()) + 1, 'níveis de dependência'], [externas, 'referências externas']])}
      <section class="cartao">
        <div class="cartao-topo"><div><h2>Mapa de dependências</h2><p class="legenda" id="grafo-contador"></p></div>
          <div class="barra-filtros">
            <label class="seletor"><span>Focar em</span><select data-dep-campo="foco"><option value="">Todos os objetos</option>${opcoes}</select></label>
            <label class="seletor"><span>Mostrar</span><select data-dep-campo="direcao"${estado.foco ? '' : ' disabled'}>
              ${opcaoDirecao('ambos', 'Cadeia completa')}${opcaoDirecao('dependencias', 'O que ele usa')}${opcaoDirecao('dependentes', 'Quem usa ele')}</select></label>
          </div></div>
        <div class="legenda-tipos" role="group" aria-label="Mostrar ou esconder tipos">${legenda}</div>
        <div class="grafo" id="grafo"></div>
        <p class="legenda" style="margin-top:12px">Colunas da esquerda para a direita: nível 0 (não depende de nada) até o último nível. Passe o mouse num objeto para destacar as ligações; clique para abrir.</p>
      </section>`;
  }

  document.addEventListener('input', (evento) => {
    const campo = evento.target.dataset?.depCampo;
    if (!campo) return;
    estado[campo] = evento.target.value;
    if (campo === 'foco') {
      const direcao = document.querySelector('[data-dep-campo="direcao"]');
      if (direcao) direcao.disabled = !evento.target.value;
    }
    desenhar();
  });

  document.addEventListener('click', (evento) => {
    const botao = evento.target.closest('[data-dep-tipo]');
    if (!botao) return;
    const tipo = botao.dataset.depTipo;
    if (estado.ocultos.has(tipo)) estado.ocultos.delete(tipo); else estado.ocultos.add(tipo);
    botao.setAttribute('aria-pressed', String(!estado.ocultos.has(tipo)));
    desenhar();
  });

  // Destaca as ligações do objeto sob o mouse.
  document.addEventListener('mouseover', (evento) => {
    const grafo = document.getElementById('grafo');
    if (!grafo) return;
    const no = evento.target.closest?.('.no');
    grafo.classList.toggle('destacando', Boolean(no));
    grafo.querySelectorAll('.aresta.ativa, .no.ligado').forEach((el) => el.classList.remove('ativa', 'ligado'));
    if (!no) return;
    const nome = no.dataset.no;
    grafo.querySelectorAll('.aresta').forEach((aresta) => {
      if (aresta.dataset.de !== nome && aresta.dataset.para !== nome) return;
      aresta.classList.add('ativa');
      const outro = aresta.dataset.de === nome ? aresta.dataset.para : aresta.dataset.de;
      grafo.querySelector(`.no[data-no="${CSS.escape(outro)}"]`)?.classList.add('ligado');
    });
    no.classList.add('ligado');
  });

  Q.paginas.registrar('dependencias', { render, aoRenderizar: desenhar, titulo: 'Dependências' });
})(window.Quimia);
