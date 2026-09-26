/* Quimia · componentes — cabeçalho de página, chips, selos, números e item de arquivo. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, hrefObjeto, hrefArquivo, curto } = Q.util;
  const { TIPOS, NIVEIS, GRUPOS, porNome } = Q;

  function cabecalho({ secao, titulo, subtitulo, voltar = false, acoes = '' }) {
    const botaoVoltar = voltar
      ? `<button class="botao-icone pequeno" data-acao="voltar" aria-label="Voltar">${icone('arrow-left')}</button>` : '';
    return `<header class="cabecalho">
      <div>${secao ? `<p class="sobretitulo">${esc(secao)}</p>` : ''}
        <div class="cabecalho-titulo">${botaoVoltar}<h1>${esc(titulo)}</h1></div>
        ${subtitulo ? `<p class="subtitulo">${subtitulo}</p>` : ''}</div>
      ${acoes}
    </header>`;
  }

  // Link para um objeto do catálogo, com o ponto na cor do tipo.
  function chip(nome) {
    const obj = porNome.get(nome);
    if (!obj) return `<span class="chip">${esc(nome)}</span>`;
    return `<a class="chip" href="${hrefObjeto(nome)}"><span class="ponto" style="--cor:${TIPOS[obj.tipo].cor}"></span>${esc(nome)}</a>`;
  }

  function seloNivel(nivel) {
    if (!nivel) return '';
    return `<span class="selo selo-${esc(nivel)}"><span class="ponto"></span>${esc(NIVEIS[nivel]?.rotulo ?? nivel)}</span>`;
  }

  function seloTipo(tipo) {
    return `<span class="selo"><span class="ponto" style="--cor:${TIPOS[tipo].cor}"></span>${esc(TIPOS[tipo].singular)}</span>`;
  }

  // Faixa de números grandes no topo das páginas. itens: [valor, rótulo, classe extra?]
  function resumoNumeros(itens) {
    return `<div class="metricas">${itens.map(([valor, rotulo, classe]) =>
      `<div class="metrica${classe ? ` ${classe}` : ''}"><span class="metrica-valor">${valor}</span><span class="metrica-rotulo">${rotulo}</span></div>`).join('')}</div>`;
  }

  function itemArquivo(arq, ativo = false) {
    return `<a class="item${ativo ? ' ativo' : ''}" href="${hrefArquivo(arq.caminho)}"${ativo ? ' aria-current="true"' : ''}>
      <span class="item-icone">${icone('file-code')}</span>
      <span class="item-texto"><strong>${esc(arq.nome)}</strong><span>${esc(curto(arq.caminho))}</span></span>
      <span class="selo">${esc(GRUPOS[arq.grupo].rotulo)}</span></a>`;
  }

  Object.assign(Q.ui, { cabecalho, chip, seloNivel, seloTipo, resumoNumeros, itemArquivo });
})(window.Quimia);
