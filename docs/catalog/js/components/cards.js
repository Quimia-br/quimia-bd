/* Quimia · componentes — cards de objeto (listagens) e de tabela (Banco de Dados). */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, hrefObjeto, plural } = Q.util;
  const { seloNivel } = Q.ui;
  const { TIPOS } = Q;

  function rodapeDependencias(obj) {
    return `<div class="card-rodape">
      <span>${icone('link')}${plural(obj.dependencias.length, 'dependência', 'dependências')}</span>
      <span>${plural(obj.usado_por.length, 'dependente', 'dependentes')}</span></div>`;
  }

  // Campos principais de cada tipo, usados no card e na seção "Definição" do detalhe.
  function camposObjeto(obj) {
    const campos = [];
    if (obj.tipo === 'view') {
      campos.push(['Domínio', esc(obj.dominio ?? '—')], ['Acesso', seloNivel(obj.nivel_acesso) || '—'], ['Colunas', obj.colunas.length]);
    } else if (obj.tipo === 'funcao' || obj.tipo === 'procedure') {
      campos.push(['Parâmetros', obj.argumentos ? `<code>${esc(obj.argumentos)}</code>` : 'nenhum', true]);
      if (obj.retorno) campos.push(['Retorno', `<code>${esc(obj.retorno)}</code>`, true]);
      campos.push(['Linguagem', esc(obj.linguagem ?? '—')]);
    } else if (obj.tipo === 'trigger') {
      campos.push(['Tabela', `<code>${esc(obj.tabela)}</code>`], ['Função', `<code>${esc(obj.funcao)}</code>`],
        ['Momento', esc(obj.momento)], ['Nível', esc(obj.nivel)], ['Eventos', esc(obj.eventos), true]);
    } else if (obj.tipo === 'indice') {
      campos.push(['Tabela', `<code>${esc(obj.tabela)}</code>`], ['Método', esc(obj.metodo) + (obj.unico ? ' · UNIQUE' : '')],
        ['Colunas', `<code>${esc(obj.colunas_indice.join(', '))}</code>`, true]);
      if (obj.condicao) campos.push(['Parcial', `<code>WHERE ${esc(obj.condicao)}</code>`, true]);
    } else if (obj.tipo === 'log' || obj.tipo === 'tabela') {
      const fks = obj.colunas.filter((c) => c.fk).length;
      campos.push(['Colunas', obj.colunas.length], ['Relacionamentos', fks], ['Acesso', seloNivel(obj.nivel_acesso) || '—']);
    }
    return `<dl class="campos">${campos.map(([rotulo, valor, largo]) =>
      `<div class="campo${largo ? ' largo' : ''}"><dt>${rotulo}</dt><dd>${valor}</dd></div>`).join('')}</dl>`;
  }

  function cardObjeto(obj) {
    return `<a class="card-objeto" href="${hrefObjeto(obj.nome)}">
      <div class="card-cabeca">${icone(TIPOS[obj.tipo].icone)}
        <div class="card-cabeca-texto"><p class="sobretitulo">${esc(TIPOS[obj.tipo].singular)}</p><h3>${esc(obj.nome)}</h3>
          <div class="selos"><span class="selo selo-mono" title="${esc(obj.arquivo)}">${esc(obj.arquivo.split('/').pop())}</span></div></div>
      </div>
      <div class="card-corpo">
        ${obj.descricao ? `<p class="card-descricao">${esc(obj.descricao)}</p>` : ''}
        ${camposObjeto(obj)}
        ${rodapeDependencias(obj)}
      </div></a>`;
  }

  function selosColuna(col) {
    return [
      col.pk ? '<span class="selo selo-pk">PK</span>' : '',
      col.fk ? '<span class="selo selo-fk">FK</span>' : '',
      col.unique && !col.pk ? '<span class="selo">UNIQUE</span>' : '',
      col.check ? '<span class="selo">CHECK</span>' : '',
      col.obrigatorio && !col.pk ? '<span class="selo">NOT NULL</span>' : '',
      col.lgpd ? '<span class="selo selo-lgpd">LGPD</span>' : ''
    ].join('');
  }

  function cardTabela(obj) {
    const fks = obj.colunas.filter((c) => c.fk).length;
    const marcador = obj.tipo === 'log' ? '<span class="selo">LOG</span>' : (fks ? `<span class="selo selo-fk">${fks} FK</span>` : '');
    const colunas = obj.colunas.map((c) => `<div class="coluna-card" title="${esc(c.descricao ?? '')}">
        ${c.pk ? icone('key-round') : c.fk ? icone('link') : '<span class="icone-vazio"></span>'}
        <span class="coluna-nome">${esc(c.nome)}</span>
        <span class="coluna-lado"><span class="coluna-tipo">${esc(c.tipo)}</span>${selosColuna(c)}</span></div>`).join('');
    return `<article class="card-objeto">
      <a class="card-cabeca" href="${hrefObjeto(obj.nome)}">${icone(TIPOS[obj.tipo].icone)}
        <div class="card-cabeca-texto"><h3>${esc(obj.nome)}</h3><span>${esc(obj.dominio ?? 'public')} · ${plural(obj.colunas.length, 'coluna', 'colunas')}</span>
          <div class="selos">${marcador}${seloNivel(obj.nivel_acesso)}</div></div>
      </a>
      <div class="card-corpo">
        ${obj.descricao ? `<p class="card-descricao">${esc(obj.descricao)}</p>` : ''}
        <div class="colunas-card">${colunas}</div>
      </div></article>`;
  }

  Object.assign(Q.ui, { camposObjeto, cardObjeto, selosColuna, cardTabela });
})(window.Quimia);
