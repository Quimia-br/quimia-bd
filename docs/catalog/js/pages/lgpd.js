/* Quimia · página LGPD (#/lgpd): objetos restritos e colunas com dado pessoal. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, hrefObjeto } = Q.util;
  const { cabecalho, chip, seloNivel } = Q.ui;
  const { dados } = Q;

  function render() {
    const restritos = dados.objetos.filter((o) => o.nivel_acesso === 'restrito');
    const colunas = dados.objetos.flatMap((o) => (o.colunas ?? []).filter((c) => c.lgpd).map((c) => ({ obj: o, col: c })));
    const grade = 'minmax(220px,1.2fr) 130px minmax(0,2.5fr)';
    const linhas = colunas.map(({ obj, col }) => `<a class="linha" href="${hrefObjeto(obj.nome)}" style="--colunas:${grade}">
      <span class="mono">${esc(obj.nome)}.${esc(col.nome)}</span><span data-rotulo="Acesso">${seloNivel(obj.nivel_acesso)}</span>
      <span data-rotulo="Descrição">${esc(col.descricao ?? '')}${col.regra_negocio ? `<span class="nota"><strong>Regra:</strong> ${esc(col.regra_negocio)}</span>` : ''}</span></a>`).join('');
    return `${cabecalho({ secao: 'Governança', titulo: 'Dados pessoais (LGPD)', subtitulo: `Objetos com acesso restrito e colunas que guardam dado pessoal. O Data Mart expõe apenas dados anonimizados; por exemplo, <a href="${hrefObjeto('dim_usuario')}"><strong>dim_usuario</strong></a> não tem nome nem e-mail.` })}
      <section class="cartao"><h2>Objetos restritos (${restritos.length})</h2><div class="chips">${restritos.map((o) => chip(o.nome)).join('')}</div></section>
      <section class="cartao"><h2>Colunas com dado pessoal (${colunas.length})</h2>
        <div class="lista"><div class="lista-cabecalho" style="--colunas:${grade}"><span>Coluna</span><span>Acesso</span><span>Descrição</span></div>${linhas}</div></section>`;
  }

  Q.paginas.registrar('lgpd', { render, titulo: 'LGPD' });
})(window.Quimia);
