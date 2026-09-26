/* Quimia · busca global do topo (Ctrl/⌘ K): objetos, colunas e arquivos. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, normalizar, hrefObjeto, hrefArquivo, curto } = Q.util;
  const { dados, TIPOS } = Q;

  const campo = document.getElementById('busca-global');
  const painel = document.getElementById('resultados-busca');
  let resultados = [];
  let selecionado = -1;

  function buscar(termo) {
    const t = normalizar(termo.trim());
    if (!t) return [];
    const objetos = dados.objetos.filter((o) => normalizar(o.nome).includes(t) || normalizar(o.descricao).includes(t))
      .slice(0, 8).map((o) => ({ grupo: 'Objetos', href: hrefObjeto(o.nome), icone: TIPOS[o.tipo].icone, titulo: o.nome, texto: `${TIPOS[o.tipo].singular} · ${o.descricao ?? ''}` }));
    const colunas = dados.objetos.flatMap((o) => (o.colunas ?? [])
      .filter((c) => normalizar(c.nome).includes(t) || normalizar(c.descricao).includes(t))
      .map((c) => ({ grupo: 'Colunas', href: hrefObjeto(o.nome), icone: 'link', titulo: `${o.nome}.${c.nome}`, texto: c.descricao ?? c.tipo ?? '' })))
      .slice(0, 8);
    const arquivos = dados.arquivos.filter((a) => normalizar(a.caminho).includes(t))
      .slice(0, 6).map((a) => ({ grupo: 'Arquivos', href: hrefArquivo(a.caminho), icone: 'file-code', titulo: a.nome, texto: curto(a.caminho) }));
    return [...objetos, ...colunas, ...arquivos];
  }

  function fechar() {
    painel.hidden = true;
    campo.setAttribute('aria-expanded', 'false');
    campo.removeAttribute('aria-activedescendant');
  }

  function mostrar() {
    if (!campo.value.trim()) { fechar(); return; }
    resultados = buscar(campo.value);
    selecionado = resultados.length ? 0 : -1;
    let grupoAtual = '';
    painel.innerHTML = resultados.length ? resultados.map((r, i) => {
      const titulo = r.grupo !== grupoAtual ? `<p class="resultados-grupo">${esc(r.grupo)}</p>` : '';
      grupoAtual = r.grupo;
      return `${titulo}<a class="resultado" role="option" id="resultado-${i}" href="${r.href}" aria-selected="${i === selecionado}">
        <span class="item-icone">${icone(r.icone)}</span>
        <span class="resultado-texto"><strong>${esc(r.titulo)}</strong><span>${esc(r.texto)}</span></span></a>`;
    }).join('') : '<p class="vazio">Nada encontrado.</p>';
    painel.hidden = false;
    campo.setAttribute('aria-expanded', 'true');
    if (selecionado >= 0) campo.setAttribute('aria-activedescendant', `resultado-${selecionado}`);
    else campo.removeAttribute('aria-activedescendant');
  }

  function marcarSelecionado() {
    painel.querySelectorAll('.resultado').forEach((el, i) => el.setAttribute('aria-selected', String(i === selecionado)));
    campo.setAttribute('aria-activedescendant', `resultado-${selecionado}`);
    painel.querySelector(`#resultado-${selecionado}`)?.scrollIntoView({ block: 'nearest' });
  }

  campo.addEventListener('input', mostrar);
  campo.addEventListener('focus', () => { if (campo.value.trim()) mostrar(); });
  campo.addEventListener('keydown', (evento) => {
    if (evento.key === 'ArrowDown' && resultados.length) { evento.preventDefault(); selecionado = (selecionado + 1) % resultados.length; marcarSelecionado(); }
    else if (evento.key === 'ArrowUp' && resultados.length) { evento.preventDefault(); selecionado = (selecionado - 1 + resultados.length) % resultados.length; marcarSelecionado(); }
    else if (evento.key === 'Enter' && selecionado >= 0) { location.hash = resultados[selecionado].href; fechar(); campo.blur(); }
    else if (evento.key === 'Escape') { fechar(); campo.blur(); }
  });

  document.addEventListener('keydown', (evento) => {
    if ((evento.ctrlKey || evento.metaKey) && evento.key.toLowerCase() === 'k') { evento.preventDefault(); campo.focus(); campo.select(); }
  });
  document.addEventListener('click', (evento) => {
    if (!evento.target.closest('.busca-global')) fechar();
  });

  if (/Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent)) document.getElementById('atalho-busca').textContent = '⌘ K';

  Q.busca = { fechar };
})(window.Quimia);
