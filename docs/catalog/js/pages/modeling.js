/* Quimia · página Modelagem (#/modelagem): diagrama físico com Mermaid e lista de FKs. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, hrefObjeto, carregarScript } = Q.util;
  const { cabecalho, abasBanco } = Q.ui;
  const { dados, porNome, DOMINIOS } = Q;

  const MERMAID = 'https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js';
  let zoom = 1;

  function codigoDiagrama(dominio) {
    const tabelas = dados.objetos.filter((o) => (o.tipo === 'tabela' || o.tipo === 'log') && (!dominio || o.dominio === dominio));
    const nomes = new Set(tabelas.map((t) => t.nome));
    const linhas = ['erDiagram'];
    for (const t of tabelas) {
      linhas.push(`  ${t.nome} {`);
      for (const c of t.colunas) {
        const chave = [c.pk ? 'PK' : '', c.fk ? 'FK' : '', c.unique && !c.pk ? 'UK' : ''].filter(Boolean).join(', ');
        const tipo = String(c.tipo || 'tipo').split(/[\s(]/)[0].toLowerCase();
        linhas.push(`    ${tipo} ${c.nome}${chave ? ' ' + chave : ''}`);
      }
      linhas.push('  }');
    }
    // Relações que cruzam o filtro de domínio entram também: a tabela da outra
    // ponta aparece só com o nome (o Mermaid cria a entidade pela relação).
    for (const r of dados.relacionamentos) {
      if (!nomes.has(r.de) && !nomes.has(r.para)) continue;
      const coluna = porNome.get(r.de).colunas.find((c) => c.nome === r.coluna);
      const pai = r.obrigatoria ? '||' : '|o';
      const filho = coluna && coluna.unique ? 'o|' : 'o{';
      linhas.push(`  ${r.para} ${pai}--${filho} ${r.de} : "${r.coluna}"`);
    }
    return linhas.join('\n');
  }

  function aplicarZoom() {
    const palco = document.querySelector('.diagrama-palco');
    if (palco) palco.style.transform = `scale(${zoom})`;
  }

  function ajustarZoom() {
    const alvo = document.getElementById('diagrama');
    const svg = alvo?.querySelector('svg');
    if (!svg) return;
    const largura = svg.getBoundingClientRect().width / zoom;
    zoom = Math.min(1, Math.max(0.2, (alvo.clientWidth - 48) / largura));
    aplicarZoom();
  }

  async function desenhar() {
    const alvo = document.getElementById('diagrama');
    if (!alvo) return;
    const dominio = document.getElementById('diagrama-dominio')?.value || '';
    alvo.innerHTML = '<p class="vazio">Carregando diagrama…</p>';
    try {
      await carregarScript(MERMAID);
      const css = getComputedStyle(document.documentElement);
      const token = (nome) => css.getPropertyValue(nome).trim();
      window.mermaid.initialize({
        startOnLoad: false, securityLevel: 'strict', theme: 'base',
        er: { useMaxWidth: false },
        themeVariables: {
          fontFamily: token('--fonte'),
          primaryColor: token('--surface-base'),
          primaryTextColor: token('--foreground-primary'),
          primaryBorderColor: token('--primary-pressed'),
          lineColor: token('--foreground-subtle'),
          tertiaryColor: token('--surface-base'),
          attributeBackgroundColorOdd: token('--surface-base'),
          attributeBackgroundColorEven: token('--surface-background')
        }
      });
      const { svg } = await window.mermaid.render(`er-${Date.now()}`, codigoDiagrama(dominio));
      alvo.innerHTML = `<div class="diagrama-palco">${svg}</div>`;
      zoom = 1;
      ajustarZoom();
    } catch (erro) {
      alvo.innerHTML = `<p class="vazio">Não foi possível desenhar o diagrama (${esc(erro.message)}). Ele usa a biblioteca Mermaid pela internet; as chaves estrangeiras continuam listadas abaixo.</p>`;
    }
  }

  function render() {
    const opcoes = DOMINIOS.filter((d) => dados.objetos.some((o) => (o.tipo === 'tabela' || o.tipo === 'log') && o.dominio === d))
      .map((d) => `<option value="${d}">${esc(d)}</option>`).join('');
    const grade = 'minmax(0,1.3fr) minmax(0,1.3fr) 130px 120px';
    const linhas = dados.relacionamentos.map((r) => `<div class="linha" style="--colunas:${grade}">
      <a class="mono" href="${hrefObjeto(r.de)}">${esc(r.de)}.${esc(r.coluna)}</a>
      <a class="mono" href="${hrefObjeto(r.para)}" data-rotulo="Referencia">${esc(r.para)}.${esc(r.coluna_ref)}</a>
      <span class="sutil" data-rotulo="Ao excluir">${esc(r.on_delete ?? 'NO ACTION')}</span><span class="sutil" data-rotulo="Preenchimento">${r.obrigatoria ? 'Obrigatória' : 'Opcional'}</span></div>`).join('');
    return `${cabecalho({ secao: 'Explorador', titulo: 'Modelagem', subtitulo: 'Diagrama físico lido dos scripts: tabelas, colunas e chaves estrangeiras. PK chave primária · FK chave estrangeira · UK valor único.' })}
      ${abasBanco('modelagem')}
      <section class="cartao">
        <div class="cartao-topo"><h2>Diagrama</h2>
          <div class="diagrama-controles">
            <label for="diagrama-dominio" class="sutil">Domínio</label>
            <select id="diagrama-dominio"><option value="">Todos</option>${opcoes}</select>
            <button class="botao-icone pequeno fundo" data-acao="zoom-menos" aria-label="Diminuir zoom">${icone('minus')}</button>
            <button class="botao" data-acao="zoom-ajustar">${icone('rotate-ccw')}Ajustar</button>
            <button class="botao-icone pequeno fundo" data-acao="zoom-mais" aria-label="Aumentar zoom">${icone('plus')}</button>
          </div></div>
        <div class="diagrama" id="diagrama"></div>
      </section>
      <section class="cartao"><h2>Chaves estrangeiras (${dados.relacionamentos.length})</h2>
        <div class="lista"><div class="lista-cabecalho" style="--colunas:${grade}"><span>Coluna</span><span>Referencia</span><span>Ao excluir</span><span>Preenchimento</span></div>${linhas}</div></section>`;
  }

  document.addEventListener('change', (evento) => {
    if (evento.target.id === 'diagrama-dominio') desenhar();
  });

  document.addEventListener('click', (evento) => {
    const acao = evento.target.closest('[data-acao]')?.dataset.acao;
    if (acao === 'zoom-mais') { zoom = Math.min(2.5, zoom * 1.25); aplicarZoom(); }
    else if (acao === 'zoom-menos') { zoom = Math.max(0.15, zoom / 1.25); aplicarZoom(); }
    else if (acao === 'zoom-ajustar') ajustarZoom();
  });

  // As cores do diagrama vêm do tema: redesenha quando o tema muda.
  document.addEventListener('quimia:tema', () => {
    if (Q.rotaAtual().pagina === 'modelagem') desenhar();
  });

  Q.paginas.registrar('modelagem', { render, aoRenderizar: desenhar, titulo: 'Modelagem' });
})(window.Quimia);
