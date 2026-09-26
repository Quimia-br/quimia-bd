/* Quimia · ferramenta Alterações Locais (#/alteracoes[/<arquivo>]): .sql diferentes do
   último commit, no momento em que o catálogo foi gerado. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, plural, curto } = Q.util;
  const { cabecalho } = Q.ui;
  const { dados } = Q;
  const { STATUS, seloStatus, contagemLinhas } = Q.diff;

  const estado = { status: 'todos', abertos: new Set() };

  function itemAlteracao(a) {
    const aberto = estado.abertos.has(a.caminho);
    return `<li class="alteracao${aberto ? ' aberta' : ''}">
      <button class="alteracao-topo" data-alt-arquivo="${esc(a.caminho)}" aria-expanded="${aberto}">
        <span class="item-icone">${icone('file-code')}</span>
        <span class="item-texto"><strong>${esc(a.caminho.split('/').pop())}</strong><span>${esc(curto(a.caminho))}${a.anterior ? ` (era ${esc(curto(a.anterior))})` : ''}</span></span>
        ${seloStatus(a.status)}${contagemLinhas(a.adicoes, a.remocoes)}
        <span class="alteracao-seta">${icone('chevron-down')}</span></button>
      <div class="alteracao-diff" id="diff-${esc(a.caminho)}">${aberto ? '<p class="legenda">Carregando…</p>' : ''}</div></li>`;
  }

  function render(parametro) {
    const alt = dados.alteracoes;
    if (!alt?.disponivel) {
      return `${cabecalho({ secao: 'Ferramentas', titulo: 'Alterações Locais' })}<p class="vazio">${esc(alt?.motivo ?? 'Indisponível.')}</p>`;
    }
    if (parametro && alt.arquivos.some((a) => a.caminho === parametro)) estado.abertos.add(parametro);
    const contagem = {};
    alt.arquivos.forEach((a) => { contagem[a.status] = (contagem[a.status] ?? 0) + 1; });
    const filtros = [['todos', 'Todos', alt.arquivos.length], ...Object.entries(contagem).map(([s, n]) => [s, STATUS[s]?.rotulo ?? s, n])]
      .map(([valor, rotulo, n]) => `<button class="filtro" data-alt-status="${valor}" aria-pressed="${estado.status === valor}">${esc(rotulo)} <span class="contagem">${n}</span></button>`).join('');
    const itens = alt.arquivos.filter((a) => estado.status === 'todos' || a.status === estado.status).map(itemAlteracao).join('');
    const gerado = new Date(dados.gerado_em).toLocaleString('pt-BR', { dateStyle: 'long', timeStyle: 'short' });
    return `${cabecalho({ secao: 'Ferramentas', titulo: 'Alterações Locais', subtitulo: `Scripts .sql de ${esc(alt.escopo)} diferentes do último commit, no momento em que o catálogo foi gerado (${esc(gerado)}). Rode o gerador de novo para atualizar.` })}
      <div class="abas" role="group" aria-label="Filtrar por situação">${filtros}</div>
      <section class="cartao">
        ${alt.arquivos.length ? `<p class="legenda" style="margin-bottom:12px">${plural(alt.arquivos.length, 'arquivo alterado', 'arquivos alterados')} em relação ao commit ${esc(dados.commit?.hash ?? 'atual')}.</p>
          <ul class="alteracoes">${itens || '<p class="vazio">Nenhum arquivo nessa situação.</p>'}</ul>`
          : '<p class="vazio">Nenhuma alteração local: os scripts estão iguais ao último commit.</p>'}
      </section>`;
  }

  function preencherDiffs() {
    const abertos = [...estado.abertos];
    if (!abertos.length) return;
    Q.diff.carregar('changes').then((diffs) => {
      for (const caminho of abertos) {
        const alvo = document.getElementById(`diff-${caminho}`);
        const arquivo = diffs.arquivos.find((a) => a.caminho === caminho);
        if (alvo && arquivo) alvo.innerHTML = Q.diff.bloco(arquivo);
      }
    }).catch((erro) => {
      abertos.forEach((c) => { const alvo = document.getElementById(`diff-${c}`); if (alvo) alvo.innerHTML = `<p class="legenda">${esc(erro.message)}</p>`; });
    });
  }

  document.addEventListener('click', (evento) => {
    const status = evento.target.closest('[data-alt-status]');
    if (status) {
      estado.status = status.dataset.altStatus;
      Q.conteudo.innerHTML = render();
      preencherDiffs();
      return;
    }
    const botao = evento.target.closest('[data-alt-arquivo]');
    if (!botao) return;
    const caminho = botao.dataset.altArquivo;
    if (estado.abertos.has(caminho)) estado.abertos.delete(caminho); else estado.abertos.add(caminho);
    const aberto = estado.abertos.has(caminho);
    const item = botao.closest('.alteracao');
    item.classList.toggle('aberta', aberto);
    botao.setAttribute('aria-expanded', String(aberto));
    item.querySelector('.alteracao-diff').innerHTML = aberto ? '<p class="legenda">Carregando…</p>' : '';
    if (aberto) preencherDiffs();
  });

  Q.paginas.registrar('alteracoes', { render, aoRenderizar: preencherDiffs, titulo: 'Alterações Locais' });
})(window.Quimia);
