/* Quimia · ferramenta Histórico (#/historico[/<commit>]): commits que tocaram .sql de src/database/sql. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, plural, curto, normalizar, dataHora } = Q.util;
  const { cabecalho } = Q.ui;
  const { dados } = Q;
  const { seloStatus, contagemLinhas } = Q.diff;

  const estado = { termo: '', abertos: new Set() };

  function filtrados() {
    const termo = normalizar(estado.termo.trim());
    return dados.historico.commits.filter((c) => !termo || normalizar(
      `${c.assunto} ${c.corpo} ${c.autor} ${c.curto} ${c.arquivos.map((a) => a.caminho).join(' ')}`).includes(termo));
  }

  function cartaoCommit(c) {
    const aberto = estado.abertos.has(c.curto);
    return `<li class="commit${aberto ? ' aberto' : ''}" id="commit-${esc(c.curto)}">
      <span class="commit-marcador">${icone('git-commit')}</span>
      <article class="cartao commit-cartao">
        <div class="commit-topo"><div class="commit-titulo"><h3>${esc(c.assunto)}</h3>
          <p class="legenda">${esc(c.autor)} · ${esc(dataHora(c.data))} · <span class="mono">${esc(c.curto)}</span></p></div>
          <div class="selos">${contagemLinhas(c.adicoes, c.remocoes)}<span class="selo">${plural(c.arquivos.length, 'arquivo', 'arquivos')}</span></div></div>
        ${c.corpo ? `<p class="commit-corpo">${esc(c.corpo)}</p>` : ''}
        <ul class="commit-arquivos">${c.arquivos.map((a) => `<li>${seloStatus(a.status)}<span class="mono">${esc(curto(a.caminho))}</span>${contagemLinhas(a.adicoes, a.remocoes)}</li>`).join('')}</ul>
        <button class="botao" data-commit="${esc(c.curto)}" aria-expanded="${aberto}">${icone(aberto ? 'minus' : 'plus')}${aberto ? 'Esconder alterações' : 'Ver alterações'}</button>
        <div class="commit-diffs" id="diffs-${esc(c.curto)}">${aberto ? '<p class="legenda">Carregando…</p>' : ''}</div>
      </article></li>`;
  }

  function lista() {
    const commits = filtrados();
    return commits.length ? `<ol class="linha-tempo">${commits.map(cartaoCommit).join('')}</ol>` : '<p class="vazio">Nenhum commit com esse filtro.</p>';
  }

  function preencherDiffs() {
    for (const curto of estado.abertos) {
      Q.diff.carregar(`commit-${curto}`).then((diff) => {
        const alvo = document.getElementById(`diffs-${curto}`);
        if (alvo) alvo.innerHTML = diff.arquivos.map(Q.diff.bloco).join('');
      }).catch((erro) => {
        const alvo = document.getElementById(`diffs-${curto}`);
        if (alvo) alvo.innerHTML = `<p class="legenda">${esc(erro.message)}</p>`;
      });
    }
  }

  function atualizarLista() {
    const alvo = document.getElementById('lista-commits');
    if (!alvo) return;
    alvo.innerHTML = lista();
    preencherDiffs();
  }

  function render(parametro) {
    const hist = dados.historico;
    if (!hist?.disponivel) {
      return `${cabecalho({ secao: 'Ferramentas', titulo: 'Histórico' })}<p class="vazio">${esc(hist?.motivo ?? 'Indisponível.')}</p>`;
    }
    if (parametro && hist.commits.some((c) => c.curto === parametro)) estado.abertos.add(parametro);
    const autores = new Set(hist.commits.map((c) => c.autor)).size;
    const primeiro = hist.commits.at(-1);
    return `${cabecalho({ secao: 'Ferramentas', titulo: 'Histórico', subtitulo: `A evolução dos scripts SQL do banco: só commits que tocaram arquivos .sql de ${esc(hist.escopo)}.` })}
      <section class="cartao historico-resumo">
        <div class="campo"><dt>Branch</dt><dd>${esc(hist.branch ?? '—')}</dd></div>
        <div class="campo"><dt>Commit atual</dt><dd class="mono">${esc(hist.commit_atual)}</dd></div>
        <div class="campo"><dt>Último commit</dt><dd>${esc(dataHora(hist.data_atual))}</dd></div>
        <div class="campo"><dt>Commits no escopo</dt><dd>${hist.commits.length}${hist.truncado ? ` (os ${hist.limite} mais recentes)` : ''}</dd></div>
        <div class="campo"><dt>Autores</dt><dd>${autores}</dd></div>
        <div class="campo"><dt>Desde</dt><dd>${primeiro ? esc(new Date(primeiro.data).toLocaleDateString('pt-BR')) : '—'}</dd></div>
      </section>
      <div class="barra-filtros">
        <label class="busca busca-local">${icone('search')}
          <input type="search" data-historico-busca value="${esc(estado.termo)}" placeholder="Filtrar por mensagem, autor ou arquivo" aria-label="Filtrar commits" autocomplete="off"></label>
      </div>
      <div id="lista-commits">${lista()}</div>`;
  }

  document.addEventListener('input', (evento) => {
    if (!evento.target.hasAttribute?.('data-historico-busca')) return;
    estado.termo = evento.target.value;
    atualizarLista();
  });

  document.addEventListener('click', (evento) => {
    const botao = evento.target.closest('[data-commit]');
    if (!botao) return;
    const curto = botao.dataset.commit;
    if (estado.abertos.has(curto)) estado.abertos.delete(curto); else estado.abertos.add(curto);
    atualizarLista();
    document.getElementById(`commit-${curto}`)?.scrollIntoView({ block: 'nearest' });
  });

  Q.paginas.registrar('historico', {
    render,
    titulo: 'Histórico',
    aoRenderizar: (parametro) => {
      preencherDiffs();
      if (parametro) document.getElementById(`commit-${parametro}`)?.scrollIntoView({ block: 'nearest' });
    }
  });
})(window.Quimia);
