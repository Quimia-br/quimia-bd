/* Quimia · aplicação — rotas, menu, tema, ações globais e inicialização.
   Carregado por último: todas as páginas já se registraram em Q.paginas. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, plural, temaEscuro, avisar } = Q.util;
  const { dados } = Q;
  const aside = document.getElementById('aside');
  const TITULO_PADRAO = 'Quimia · Catálogo de Dados';

  // #/<pagina>/<parametro...>. Um último segmento L<n> vira `linha`
  // (#/scripts/<arquivo>/L12 abre o arquivo com a linha 12 destacada).
  function rotaAtual() {
    const [pagina, ...resto] = location.hash.replace(/^#\/?/, '').split('/');
    const linha = /^L\d+$/.test(resto.at(-1) ?? '') ? Number(resto.pop().slice(1)) : null;
    const parametro = resto.length ? decodeURIComponent(resto.join('/')) : null;
    const definicao = Q.paginas.obter(pagina);
    return definicao
      ? { pagina, parametro, linha, definicao }
      : { pagina: 'inicio', parametro: null, linha: null, definicao: Q.paginas.obter('inicio') };
  }

  function marcarMenu(secao) {
    document.querySelectorAll('.nav-item').forEach((a) => {
      const ativo = a.dataset.rota === secao;
      a.classList.toggle('ativo', ativo);
      if (ativo) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
    });
  }

  function render() {
    const rota = rotaAtual();
    const { definicao, parametro } = rota;
    Q.conteudo.innerHTML = definicao.render(parametro, rota);
    marcarMenu(definicao.secaoNav?.(parametro) ?? rota.pagina);
    const titulo = typeof definicao.titulo === 'function' ? definicao.titulo(parametro) : definicao.titulo;
    document.title = titulo ? `${titulo} · Quimia` : TITULO_PADRAO;
    fecharMenu();
    Q.busca?.fechar();
    if (!definicao.manterRolagem?.(parametro)) window.scrollTo(0, 0);
    definicao.aoRenderizar?.(parametro, rota);
  }

  function fecharMenu() {
    aside.classList.remove('aberto');
    document.querySelector('[data-acao="menu"]').setAttribute('aria-expanded', 'false');
  }

  function atualizarBotaoTema() {
    const escuro = temaEscuro();
    const botao = document.getElementById('botao-tema');
    botao.innerHTML = icone(escuro ? 'sun' : 'moon');
    botao.setAttribute('aria-label', escuro ? 'Usar tema claro' : 'Usar tema escuro');
  }

  // Ações que valem em qualquer página (as de cada página ficam no próprio arquivo).
  document.addEventListener('click', (evento) => {
    if (aside.classList.contains('aberto') && !evento.target.closest('.aside, [data-acao="menu"]')) fecharMenu();
    const botao = evento.target.closest('[data-acao]');
    const acao = botao?.dataset.acao;
    if (acao === 'voltar') {
      if (history.length > 1) history.back(); else location.hash = '#/';
    } else if (acao === 'menu') {
      botao.setAttribute('aria-expanded', String(aside.classList.toggle('aberto')));
    } else if (acao === 'tema') {
      const novo = temaEscuro() ? 'light' : 'dark';
      document.documentElement.dataset.theme = novo;
      try { localStorage.setItem('quimia-catalogo-tema', novo); } catch (_) { /* armazenamento indisponível */ }
      atualizarBotaoTema();
      document.dispatchEvent(new CustomEvent('quimia:tema', { detail: novo }));
    } else if (acao === 'copiar') {
      const texto = botao.closest('.codigo').querySelector('.codigo-texto').textContent;
      navigator.clipboard?.writeText(texto).then(() => avisar('SQL copiado'), () => avisar('Não foi possível copiar'));
    }
  });

  // Contadores do menu e rodapé do aside.
  function preencherMenu() {
    document.querySelectorAll('[data-icone]').forEach((el) => { el.outerHTML = icone(el.dataset.icone); });
    const contagens = {
      ...dados.contagens,
      arquivos: dados.arquivos.length,
      banco: (dados.contagens.tabela ?? 0) + (dados.contagens.log ?? 0),
      historico: dados.historico?.commits?.length || '',
      alteracoes: dados.alteracoes?.arquivos?.length || '',
      plano: dados.plano?.verificacoes?.length || ''
    };
    document.querySelectorAll('[data-contagem]').forEach((el) => { el.textContent = contagens[el.dataset.contagem] ?? ''; });
    const gerado = new Date(dados.gerado_em).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' });
    document.getElementById('rodape-aside').innerHTML =
      `<strong>${plural(dados.objetos.length, 'objeto', 'objetos')} documentados</strong><span>Gerado em ${esc(gerado)}${dados.commit ? ` · ${esc(dados.commit.hash)}` : ''}</span>`;
  }

  Q.rotaAtual = rotaAtual;
  Q.render = render;

  try {
    const salvo = localStorage.getItem('quimia-catalogo-tema');
    if (salvo === 'light' || salvo === 'dark') document.documentElement.dataset.theme = salvo;
  } catch (_) { /* armazenamento indisponível */ }
  preencherMenu();
  atualizarBotaoTema();
  window.addEventListener('hashchange', render);
  render();
})(window.Quimia);
