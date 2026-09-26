/* Quimia · ferramentas — diffs de git, compartilhados por Alterações Locais e Histórico.
   Os diffs ficam em docs/catalog/diffs/<nome>.js e só são carregados quando abertos. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, curto, hrefArquivo, carregarScript } = Q.util;
  const { porArquivo } = Q;

  const STATUS = {
    adicionado: { rotulo: 'Adicionado', classe: 'selo-status-add' },
    modificado: { rotulo: 'Modificado', classe: 'selo-status-mod' },
    removido: { rotulo: 'Removido', classe: 'selo-status-del' },
    renomeado: { rotulo: 'Renomeado', classe: 'selo-status-mod' },
    copiado: { rotulo: 'Copiado', classe: 'selo-status-mod' },
    nao_versionado: { rotulo: 'Não versionado', classe: 'selo-status-add' }
  };

  async function carregar(nome) {
    window.CATALOGO_DIFFS = window.CATALOGO_DIFFS || {};
    if (!window.CATALOGO_DIFFS[nome]) await carregarScript(`diffs/${nome}.js`);
    return window.CATALOGO_DIFFS[nome];
  }

  function seloStatus(status) {
    const info = STATUS[status] ?? { rotulo: status, classe: '' };
    return `<span class="selo ${info.classe}">${info.rotulo}</span>`;
  }

  function contagemLinhas(adicoes, remocoes) {
    return `<span class="diff-contagem"><span class="mais">+${adicoes}</span> <span class="menos">−${remocoes}</span></span>`;
  }

  // Diff de um arquivo, com a numeração antiga e nova lida dos cabeçalhos @@.
  function bloco(arquivo) {
    if (arquivo.binario) return '<p class="legenda">Arquivo binário: sem diff de texto.</p>';
    if (!arquivo.linhas.length) return '<p class="legenda">Sem alterações de conteúdo (arquivo vazio ou só renomeado).</p>';
    let antiga = 0;
    let nova = 0;
    const linhas = arquivo.linhas.map(([tipo, texto]) => {
      if (tipo === 'meta') {
        const m = /@@ -(\d+)(?:,\d+)? \+(\d+)/.exec(texto);
        if (m) { antiga = Number(m[1]); nova = Number(m[2]); }
        return `<tr class="diff-meta"><td></td><td></td><td>${esc(texto)}</td></tr>`;
      }
      const numAntiga = tipo === 'add' ? '' : antiga++;
      const numNova = tipo === 'del' ? '' : nova++;
      const sinal = tipo === 'add' ? '+' : tipo === 'del' ? '−' : ' ';
      return `<tr class="diff-${tipo}"><td>${numAntiga}</td><td>${numNova}</td><td><span class="diff-sinal">${sinal}</span>${esc(texto)}</td></tr>`;
    }).join('');
    return `<div class="diff">
      <div class="codigo-barra"><span>${esc(curto(arquivo.caminho))}</span>
        ${porArquivo.has(arquivo.caminho) ? `<a class="botao" href="${hrefArquivo(arquivo.caminho)}">Ver arquivo atual</a>` : ''}</div>
      <div class="diff-corpo"><table><tbody>${linhas}</tbody></table></div>
      ${arquivo.truncado ? '<p class="legenda diff-aviso">Diff muito grande: mostrando só o começo.</p>' : ''}
    </div>`;
  }

  Q.diff = { STATUS, carregar, seloStatus, contagemLinhas, bloco };
})(window.Quimia);
