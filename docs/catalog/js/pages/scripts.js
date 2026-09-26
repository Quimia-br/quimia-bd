/* Quimia · página Scripts (#/scripts[/<arquivo>[/L<linha>]]): arquivos SQL do repositório. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, plural, curto, tamanho, dataCurta } = Q.util;
  const { cabecalho, chip, itemArquivo, blocoCodigo } = Q.ui;
  const { dados, GRUPOS, porNome, porArquivo } = Q;

  let grupoAtual = 'todos';

  // Resumo de um script de carga: operações e tabelas escritas e lidas.
  // Também usado pela página Data Load.
  function resumoCarga(carga) {
    const tabelas = (lista) => (lista.length ? `<div class="chips">${lista.map(chip).join('')}</div>` : '<p class="legenda">Nenhuma.</p>');
    return `<div class="selos">
        <span class="selo">${plural(carga.comandos, 'comando', 'comandos')}</span>
        ${carga.operacoes.map((o) => `<span class="selo selo-mono">${esc(o)}</span>`).join('')}
      </div>
      <div class="grade-2" style="gap:16px">
        <div><p class="rotulo-bloco">Escreve em</p>${tabelas(carga.escreve)}</div>
        <div><p class="rotulo-bloco">Lê de</p>${tabelas(carga.le)}</div>
      </div>`;
  }

  function visualizacao(arquivo, linha) {
    if (!arquivo) return '<p class="vazio">Nenhum arquivo neste grupo.</p>';
    const objetos = arquivo.objetos.filter((n) => porNome.has(n));
    const achados = [];
    if (objetos.length) achados.push(`<p class="rotulo-bloco">Objetos definidos neste arquivo</p><div class="chips">${objetos.map(chip).join('')}</div>`);
    if (arquivo.fks) achados.push(`<p class="legenda">${plural(arquivo.fks, 'chave estrangeira', 'chaves estrangeiras')} (ALTER TABLE ... ADD CONSTRAINT).</p>`);
    if (arquivo.comentarios) achados.push(`<p class="legenda">${plural(arquivo.comentarios, 'COMMENT ON', 'COMMENT ON')} com descrições do catálogo.</p>`);
    if (arquivo.carga) achados.push(resumoCarga(arquivo.carga));
    if (!achados.length) achados.push('<p class="legenda">Nenhum objeto interpretado neste arquivo.</p>');
    return `<p class="sobretitulo">${esc(GRUPOS[arquivo.grupo].rotulo)}</p>
      <h2 style="margin-bottom:12px">${esc(arquivo.nome)}</h2>
      <div class="selos" style="margin-bottom:20px">
        <span class="selo selo-mono">${esc(curto(arquivo.caminho))}</span>
        <span class="selo">${esc(tamanho(arquivo.bytes))}</span>
        <span class="selo">${plural(arquivo.linhas, 'linha', 'linhas')}</span>
        <span class="selo">${arquivo.versionado ? `Commit de ${esc(dataCurta(arquivo.alterado_em))}` : 'Ainda não commitado'}</span>
      </div>
      <div class="pilha" style="margin-bottom:20px">${achados.join('')}</div>
      ${linha ? `<p class="legenda" style="margin-bottom:10px">Linha ${linha} destacada.</p>` : ''}
      ${blocoCodigo(arquivo.conteudo, arquivo.caminho, linha)}`;
  }

  function render(caminho, rota) {
    const grupos = [['todos', 'Todos', dados.arquivos.length]].concat(Object.entries(GRUPOS)
      .map(([g, info]) => [g, info.rotulo, dados.arquivos.filter((a) => a.grupo === g).length]).filter(([, , n]) => n));
    const lista = dados.arquivos.filter((a) => grupoAtual === 'todos' || a.grupo === grupoAtual);
    const selecionado = porArquivo.get(caminho) ?? lista[0];

    return `${cabecalho({ secao: 'Explorador', titulo: 'Scripts', subtitulo: 'Os arquivos SQL reais do repositório, inclusive os de carga que não geram objetos.' })}
      <div class="abas" role="group" aria-label="Filtrar por grupo">${grupos.map(([g, rotulo, n]) =>
        `<button class="filtro" data-grupo="${g}" aria-pressed="${grupoAtual === g}">${esc(rotulo)} <span class="contagem">${n}</span></button>`).join('')}</div>
      <div class="scripts">
        <section class="cartao scripts-lista"><h2>${plural(lista.length, 'arquivo', 'arquivos')}</h2>
          <div class="itens">${lista.map((a) => itemArquivo(a, selecionado && a.caminho === selecionado.caminho)).join('')}</div></section>
        <section class="cartao">${visualizacao(selecionado, rota.linha)}</section>
      </div>`;
  }

  document.addEventListener('click', (evento) => {
    const grupo = evento.target.closest('[data-grupo]');
    if (!grupo) return;
    grupoAtual = grupo.dataset.grupo;
    if (location.hash === '#/scripts') Q.render(); else location.hash = '#/scripts';
  });

  Q.paginas.registrar('scripts', {
    render,
    titulo: (caminho) => (caminho ? caminho.split('/').pop() : 'Scripts'),
    // Trocar de arquivo mantém a rolagem da lista; um link de linha rola até ela.
    manterRolagem: (caminho) => Boolean(caminho),
    aoRenderizar: (_caminho, rota) => {
      if (rota.linha) document.querySelector('.linha-destaque')?.scrollIntoView({ block: 'center' });
    }
  });

  Q.ui.resumoCarga = resumoCarga;
})(window.Quimia);
