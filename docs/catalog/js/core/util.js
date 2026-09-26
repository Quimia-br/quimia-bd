/* Quimia · núcleo — utilitários sem HTML de componente: escape, links, textos e datas. */
(function (Q) {
  'use strict';
  if (!Q) return;

  function esc(valor) {
    return String(valor ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  }

  function icone(nome) {
    return `<span class="icone" aria-hidden="true">${Q.icones[nome] ?? ''}</span>`;
  }

  const hrefObjeto = (nome) => `#/objeto/${encodeURIComponent(nome)}`;
  const hrefArquivo = (caminho) => `#/scripts/${encodeURIComponent(caminho)}`;
  const curto = (caminho) => caminho.replace(/^src\/database\/sql\//, '');

  function plural(n, um, varios) {
    return `${n} ${n === 1 ? um : varios}`;
  }

  // Sem acentos e em minúsculas, para buscas.
  function normalizar(texto) {
    return String(texto ?? '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();
  }

  function temaEscuro() {
    const forcado = document.documentElement.dataset.theme;
    return forcado ? forcado === 'dark' : window.matchMedia('(prefers-color-scheme: dark)').matches;
  }

  function dataCurta(iso) {
    return new Date(iso).toLocaleDateString('pt-BR', { day: '2-digit', month: 'short', year: 'numeric' });
  }

  function dataHora(iso) {
    return new Date(iso).toLocaleString('pt-BR', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  }

  function tamanho(bytes) {
    return bytes < 1024 ? `${bytes} bytes` : `${(bytes / 1024).toFixed(1).replace('.', ',')} KB`;
  }

  function avisar(texto) {
    const aviso = document.createElement('div');
    aviso.className = 'aviso-flutuante';
    aviso.setAttribute('role', 'status');
    aviso.textContent = texto;
    document.body.appendChild(aviso);
    setTimeout(() => aviso.remove(), 1800);
  }

  // Carrega um .js sob demanda (diffs, Mermaid). Funciona em file://, ao
  // contrário de fetch; cada endereço é pedido uma vez só.
  const carregados = new Map();
  function carregarScript(src) {
    if (!carregados.has(src)) {
      carregados.set(src, new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = src;
        script.onload = resolve;
        script.onerror = () => { carregados.delete(src); reject(new Error(`não foi possível carregar ${src}`)); };
        document.head.appendChild(script);
      }));
    }
    return carregados.get(src);
  }

  Object.assign(Q.util, {
    esc, icone, hrefObjeto, hrefArquivo, curto, plural, normalizar,
    temaEscuro, dataCurta, dataHora, tamanho, avisar, carregarScript
  });
})(window.Quimia);
