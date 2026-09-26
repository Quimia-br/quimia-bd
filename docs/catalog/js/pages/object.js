/* Quimia · página de detalhe de um objeto (#/objeto/<nome>). */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, curto, hrefArquivo } = Q.util;
  const { cabecalho, chip, seloNivel, seloTipo, camposObjeto, selosColuna, blocoCodigo } = Q.ui;
  const { TIPOS, porNome } = Q;

  function secaoColunas(obj) {
    const ehView = obj.tipo === 'view';
    const colunas = ehView ? 'minmax(160px,1fr) minmax(0,3fr)' : 'minmax(150px,1fr) minmax(110px,.8fr) minmax(150px,1fr) minmax(0,2.4fr)';
    const cabecalhoLista = ehView ? '<span>Coluna</span><span>Descrição</span>' : '<span>Coluna</span><span>Tipo</span><span>Restrições</span><span>Descrição</span>';
    const linhas = obj.colunas.map((col) => {
      const notas = [
        col.fk ? `<span class="nota">Referencia ${chip(col.fk.tabela)} <code>${esc(col.fk.colunas.join(', '))}</code>${col.fk.on_delete ? ` · ON DELETE ${esc(col.fk.on_delete)}` : ''}</span>` : '',
        col.default ? `<span class="nota">Padrão: <code>${esc(col.default)}</code></span>` : '',
        col.identity ? '<span class="nota">Gerado automaticamente (IDENTITY)</span>' : '',
        col.check ? `<span class="nota">CHECK: <code>${esc(col.check)}</code></span>` : '',
        col.regra_negocio ? `<span class="nota"><strong>Regra:</strong> ${esc(col.regra_negocio)}</span>` : ''
      ].join('');
      return `<div class="linha" style="--colunas:${colunas}">
        <span class="mono">${esc(col.nome)}</span>
        ${ehView ? '' : `<span class="mono sutil" data-rotulo="Tipo">${esc(col.tipo)}</span><span class="selos" data-rotulo="Restrições">${selosColuna(col)}</span>`}
        <span data-rotulo="Descrição">${esc(col.descricao ?? '')}${notas}</span></div>`;
    }).join('');
    return `<section class="cartao"><h2>Colunas (${obj.colunas.length})</h2>
      <div class="lista"><div class="lista-cabecalho" style="--colunas:${colunas}">${cabecalhoLista}</div>${linhas}</div></section>`;
  }

  function secaoRestricoes(obj) {
    const lista = (obj.constraints ?? []).filter((c) => c.tipo !== 'FOREIGN KEY' || (c.colunas ?? []).length > 1);
    if (!lista.length) return '';
    const colunas = 'minmax(160px,1fr) 130px minmax(0,3fr)';
    return `<section class="cartao"><h2>Restrições da tabela</h2><div class="lista">
      ${lista.map((c) => `<div class="linha" style="--colunas:${colunas}">
        <span class="mono">${esc(c.nome ?? '—')}</span><span class="sutil" data-rotulo="Tipo">${esc(c.tipo)}</span>
        <code data-rotulo="Definição">${esc(c.expressao ?? (c.colunas ?? []).join(', '))}</code></div>`).join('')}
      </div></section>`;
  }

  function render(nome) {
    const obj = porNome.get(nome);
    if (!obj) {
      return cabecalho({ titulo: 'Objeto não encontrado', voltar: true, subtitulo: `<code>${esc(nome)}</code> não existe no catálogo.` });
    }
    const selos = [seloTipo(obj.tipo), obj.dominio ? `<span class="selo">${esc(obj.dominio)}</span>` : '', seloNivel(obj.nivel_acesso)].join('');
    const deps = obj.dependencias.length ? `<div class="chips">${obj.dependencias.map(chip).join('')}</div>` : '<p class="legenda">Nenhuma.</p>';
    const usado = obj.usado_por.length ? `<div class="chips">${obj.usado_por.map(chip).join('')}</div>` : '<p class="legenda">Nenhum objeto.</p>';
    const temDefinicao = !['tabela', 'log', 'view'].includes(obj.tipo);
    const secao = obj.tipo === 'tabela' ? 'Explorador' : 'Objetos';
    const acoes = `<div class="abas">
      <a class="aba" href="#/impacto/${encodeURIComponent(obj.nome)}">${icone('circle-alert')}Analisar impacto</a>
      <a class="aba" href="#/dependencias/${encodeURIComponent(obj.nome)}">${icone('link')}Ver dependências</a></div>`;

    return `${cabecalho({ secao: `${secao} · ${TIPOS[obj.tipo].singular}`, titulo: obj.nome, voltar: true, acoes })}
      <section class="cartao pilha">
        <div class="selos">${selos}</div>
        ${obj.descricao ? `<p class="descricao">${esc(obj.descricao)}</p>` : '<p class="descricao legenda">Sem descrição (falta COMMENT ON).</p>'}
        ${obj.regra_negocio ? `<p class="regra"><strong>Regra de negócio:</strong> ${esc(obj.regra_negocio)}</p>` : ''}
        <dl class="meta">
          ${obj.responsavel ? `<dt>Responsável</dt><dd>${esc(obj.responsavel)}</dd>` : ''}
          <dt>Arquivo</dt><dd><a class="mono" href="${hrefArquivo(obj.arquivo)}">${esc(curto(obj.arquivo))}</a></dd>
        </dl>
      </section>
      ${temDefinicao ? `<section class="cartao"><h2>Definição</h2>${camposObjeto(obj)}</section>` : ''}
      ${obj.colunas && obj.colunas.length ? secaoColunas(obj) : ''}
      ${secaoRestricoes(obj)}
      <section class="cartao"><h2>Dependências</h2><div class="grade-2">
        <div><p class="rotulo-bloco">Depende de</p>${deps}</div><div><p class="rotulo-bloco">Usado por</p>${usado}</div></div></section>
      <section class="cartao"><h2>SQL</h2>${blocoCodigo(obj.sql, obj.arquivo)}</section>`;
  }

  Q.paginas.registrar('objeto', {
    render,
    titulo: (nome) => nome,
    // O menu marca a página que lista esse tipo de objeto.
    secaoNav: (nome) => TIPOS[porNome.get(nome)?.tipo]?.pagina
  });
})(window.Quimia);
