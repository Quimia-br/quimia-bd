/* Quimia · ferramenta Análise de Impacto.
   Link compartilhável: #/impacto/<objeto>[/<mudanca>[/<coluna>[/<novo>]]]. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, plural, curto, hrefArquivo } = Q.util;
  const { cabecalho, chip, blocoCodigo } = Q.ui;
  const { dados, porNome, TIPOS } = Q;

  const MUDANCAS = {
    renomear_coluna: { rotulo: 'Renomear coluna', coluna: true, novo: 'Novo nome da coluna' },
    alterar_tipo: { rotulo: 'Alterar tipo da coluna', coluna: true, novo: 'Novo tipo (ex.: VARCHAR(500))' },
    remover_coluna: { rotulo: 'Remover coluna', coluna: true },
    renomear_objeto: { rotulo: 'Renomear objeto', novo: 'Novo nome do objeto' },
    remover_objeto: { rotulo: 'Remover objeto' }
  };
  const TIPOS_COM_COLUNA = ['tabela', 'log', 'view'];

  let estado = { objeto: '', mudanca: '', coluna: '', novo: '', resultado: null };

  const mudancasPara = (obj) => Object.keys(MUDANCAS).filter((m) => !MUDANCAS[m].coluna || TIPOS_COM_COLUNA.includes(obj.tipo));
  const escRegex = (texto) => texto.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  // Nome como palavra inteira (não casa com prefixo/sufixo de outro identificador).
  const palavra = (nome) => new RegExp(`(^|[^\\w$])${escRegex(nome)}(?![\\w$])`, 'i');

  function ocorrencias(padrao, filtroArquivo) {
    const achados = [];
    for (const arquivo of dados.arquivos) {
      if (filtroArquivo && !filtroArquivo(arquivo)) continue;
      const encontradas = [];
      arquivo.conteudo.split('\n').forEach((texto, i) => {
        if (padrao.test(texto)) encontradas.push({ linha: i + 1, texto: texto.trim().slice(0, 180) });
      });
      if (encontradas.length) achados.push({ arquivo: arquivo.caminho, linhas: encontradas });
    }
    return achados;
  }

  function motivoDependente(dependente, alvo) {
    const motivos = {
      tabela: 'tem chave estrangeira para este objeto',
      log: 'tem chave estrangeira para este objeto',
      view: 'a view lê este objeto',
      trigger: alvo.tipo === 'funcao' ? 'a trigger executa esta função' : 'a trigger dispara nesta tabela',
      indice: 'o índice é sobre esta tabela',
      funcao: 'o corpo da função usa este objeto (só falha ao executar)',
      procedure: 'o corpo da procedure usa este objeto (só falha ao executar)'
    };
    return motivos[dependente.tipo] ?? 'depende deste objeto';
  }

  function analisar() {
    const { objeto, mudanca, coluna, novo } = estado;
    const obj = porNome.get(objeto);
    if (!obj || !mudanca) return null;
    const precisa = []; const verificar = []; const notas = [];
    const vistos = new Set([obj.nome]);
    const adicionar = (lista, nome, motivo) => { if (!vistos.has(nome)) { vistos.add(nome); lista.push({ nome, motivo }); } };
    const indiretos = (origens) => {
      const fila = [...origens];
      while (fila.length) {
        const atual = fila.shift();
        for (const n of porNome.get(atual)?.usado_por ?? []) {
          if (!vistos.has(n)) { adicionar(verificar, n, `depende de ${atual}, que é afetado`); fila.push(n); }
        }
      }
    };
    let linhas; let sql;

    if (MUDANCAS[mudanca].coluna) {
      const col = obj.colunas.find((c) => c.nome === coluna);
      if (!col) return null;
      const reColuna = palavra(col.nome);
      const reObjeto = palavra(obj.nome);
      // FKs de outras tabelas que apontam para esta coluna.
      for (const r of dados.relacionamentos.filter((r) => r.para === obj.nome && r.coluna_ref === col.nome)) {
        const motivo = mudanca === 'remover_coluna' ? `a FK ${r.de}.${r.coluna} aponta para esta coluna (o DROP falha sem CASCADE)`
          : mudanca === 'alterar_tipo' ? `a FK ${r.de}.${r.coluna} precisa mudar para o mesmo tipo`
            : `a FK ${r.de}.${r.coluna} aponta para esta coluna (o banco acompanha; o foreign_keys.sql precisa ser editado)`;
        adicionar(precisa, r.de, motivo);
      }
      if (col.fk) notas.push(`Esta coluna é chave estrangeira para ${col.fk.tabela}.${col.fk.colunas.join(', ')}${mudanca === 'remover_coluna' ? ': a constraint é removida junto.' : '.'}`);
      if (col.pk) notas.push('Esta coluna é a chave primária da tabela.');
      for (const dep of obj.usado_por.map((n) => porNome.get(n))) {
        if (dep.tipo === 'indice') {
          if (dep.colunas_indice.some((c) => reColuna.test(c))) {
            adicionar(precisa, dep.nome, mudanca === 'remover_coluna' ? 'o índice usa esta coluna e é removido junto' : 'o índice usa esta coluna');
          }
        } else if (reColuna.test(dep.sql)) {
          const motivo = dep.tipo === 'view'
            ? (mudanca === 'renomear_coluna' ? 'a view cita a coluna (o banco acompanha a mudança; o script da view precisa ser editado)'
              : mudanca === 'alterar_tipo' ? 'a view usa a coluna: o PostgreSQL não altera o tipo sem recriar a view'
                : 'a view usa a coluna: o DROP falha sem CASCADE')
            : `${motivoDependente(dep, obj)} e cita a coluna`;
          adicionar(precisa, dep.nome, motivo);
        }
      }
      indiretos(precisa.map((p) => p.nome));
      const nomeComum = dados.objetos.filter((o) => (o.colunas ?? []).some((c) => c.nome === col.nome)).length > 2;
      if (nomeComum) notas.push(`"${col.nome}" existe em várias tabelas: algumas linhas abaixo podem ser de outra tabela. Confira cada uma.`);
      linhas = ocorrencias(reColuna, (a) => reObjeto.test(a.conteudo));
      const destino = novo.trim();
      sql = mudanca === 'renomear_coluna' ? `ALTER TABLE ${obj.nome} RENAME COLUMN ${col.nome} TO ${destino || 'novo_nome'};`
        : mudanca === 'alterar_tipo' ? `ALTER TABLE ${obj.nome} ALTER COLUMN ${col.nome} TYPE ${destino || 'NOVO_TIPO'} USING ${col.nome}::${destino || 'NOVO_TIPO'};`
          : `ALTER TABLE ${obj.nome} DROP COLUMN ${col.nome};`;
      if (obj.tipo === 'view') {
        notas.push('Numa view, a mudança é feita reescrevendo o SELECT no arquivo da view (CREATE OR REPLACE VIEW).');
        sql = `-- Edite o SELECT em ${obj.arquivo} e rode o setup de novo.`;
      }
    } else {
      for (const n of obj.usado_por) adicionar(precisa, n, motivoDependente(porNome.get(n), obj));
      indiretos(precisa.map((p) => p.nome));
      linhas = ocorrencias(palavra(obj.nome));
      const destino = novo.trim() || 'novo_nome';
      const [comando, sufixo] = {
        tabela: ['TABLE', ''], log: ['TABLE', ''], view: ['VIEW', ''], indice: ['INDEX', ''],
        funcao: ['FUNCTION', `(${obj.argumentos ?? ''})`], procedure: ['PROCEDURE', `(${obj.argumentos ?? ''})`],
        trigger: ['TRIGGER', ` ON ${obj.tabela}`]
      }[obj.tipo];
      if (mudanca === 'renomear_objeto') {
        sql = obj.tipo === 'trigger' ? `ALTER TRIGGER ${obj.nome} ON ${obj.tabela} RENAME TO ${destino};`
          : `ALTER ${comando} ${obj.nome}${sufixo} RENAME TO ${destino};`;
        notas.push('No banco em uso, views, FKs, triggers e índices acompanham o novo nome (o PostgreSQL liga os objetos por identificador, não por nome). Functions e procedures quebram na próxima execução, e todos os scripts do repositório que citam o nome precisam ser editados antes do próximo setup.');
      } else {
        sql = `DROP ${comando} ${obj.nome}${sufixo};`;
        if (precisa.length) notas.push(`Sem CASCADE o DROP falha, porque há ${precisa.length} objeto(s) dependente(s). Com CASCADE, views, triggers, índices e FKs dependentes são removidos junto.`);
      }
    }
    if (['tabela', 'log'].includes(obj.tipo)) notas.push('O backend Java usa este banco a partir de outro repositório e não entra nesta análise: combine a mudança com o time do backend.');
    return { obj, precisa, verificar, notas, linhas, sql };
  }

  function formulario() {
    const obj = porNome.get(estado.objeto);
    const opcoesObjeto = Object.entries(TIPOS).map(([tipo, info]) => {
      const itens = dados.objetos.filter((o) => o.tipo === tipo);
      return itens.length ? `<optgroup label="${esc(info.rotulo)}">${itens.map((o) =>
        `<option value="${esc(o.nome)}"${o.nome === estado.objeto ? ' selected' : ''}>${esc(o.nome)}</option>`).join('')}</optgroup>` : '';
    }).join('');
    const mudancas = obj ? mudancasPara(obj) : [];
    const mudanca = MUDANCAS[estado.mudanca];
    const colunas = obj && mudanca?.coluna ? obj.colunas : [];
    const pronto = obj && mudanca && (!mudanca.coluna || estado.coluna);
    return `<form class="formulario" id="form-impacto">
      <label class="campo-form"><span>Objeto</span>
        <select data-impacto-campo="objeto" required><option value="">Escolha um objeto</option>${opcoesObjeto}</select></label>
      <label class="campo-form"><span>Tipo de mudança</span>
        <select data-impacto-campo="mudanca"${obj ? '' : ' disabled'} required><option value="">Escolha a mudança</option>${mudancas.map((m) =>
          `<option value="${m}"${m === estado.mudanca ? ' selected' : ''}>${MUDANCAS[m].rotulo}</option>`).join('')}</select></label>
      ${mudanca?.coluna ? `<label class="campo-form"><span>Coluna</span>
        <select data-impacto-campo="coluna" required><option value="">Escolha a coluna</option>${colunas.map((c) =>
          `<option value="${esc(c.nome)}"${c.nome === estado.coluna ? ' selected' : ''}>${esc(c.nome)}${c.tipo ? ` · ${esc(c.tipo)}` : ''}</option>`).join('')}</select></label>` : ''}
      ${mudanca?.novo ? `<label class="campo-form"><span>${mudanca.novo} <em>(opcional)</em></span>
        <input data-impacto-campo="novo" value="${esc(estado.novo)}" autocomplete="off"></label>` : ''}
      <button class="botao primario" type="submit"${pronto ? '' : ' disabled'}>${icone('zap')}Analisar impacto</button>
    </form>`;
  }

  function resultado() {
    const r = estado.resultado;
    if (!r) return '<p class="vazio">Escolha um objeto e o tipo de mudança para ver o que é afetado.</p>';
    const lista = (itens, vazio) => (itens.length ? `<ul class="impacto-lista">${itens.map((i) =>
      `<li>${chip(i.nome)}<span>${esc(i.motivo)}</span></li>`).join('')}</ul>` : `<p class="legenda">${vazio}</p>`);
    const totalLinhas = r.linhas.reduce((s, a) => s + a.linhas.length, 0);
    const linhas = r.linhas.map((a) => `<details class="impacto-arquivo"${r.linhas.length <= 4 ? ' open' : ''}>
        <summary><span class="mono">${esc(curto(a.arquivo))}</span><span class="selo">${plural(a.linhas.length, 'linha', 'linhas')}</span></summary>
        <ul>${a.linhas.map((l) => `<li><a href="${hrefArquivo(a.arquivo)}/L${l.linha}" class="impacto-linha"><span class="impacto-num">L${l.linha}</span><code>${esc(l.texto)}</code></a></li>`).join('')}</ul>
      </details>`).join('');
    const mudanca = MUDANCAS[estado.mudanca];
    return `<div class="pilha">
      <div><p class="sobretitulo">Resultado</p><h2 style="margin:0">${esc(r.obj.nome)}${estado.coluna && mudanca.coluna ? `.${esc(estado.coluna)}` : ''}</h2>
        <p class="legenda">Simulação: ${esc(mudanca.rotulo.toLowerCase())}.</p></div>
      <div class="impacto-numeros">
        <div class="impacto-numero ${r.precisa.length ? 'alto' : ''}"><strong>${r.precisa.length}</strong><span>precisam mudar</span></div>
        <div class="impacto-numero ${r.verificar.length ? 'medio' : ''}"><strong>${r.verificar.length}</strong><span>para verificar</span></div>
        <div class="impacto-numero"><strong>${r.linhas.length}</strong><span>${r.linhas.length === 1 ? 'arquivo' : 'arquivos'}</span></div>
        <div class="impacto-numero"><strong>${totalLinhas}</strong><span>${totalLinhas === 1 ? 'linha' : 'linhas'}</span></div>
      </div>
      ${r.notas.map((n) => `<p class="regra">${esc(n)}</p>`).join('')}
      <div><h3 class="impacto-titulo">${icone('circle-alert')}Precisam mudar</h3>${lista(r.precisa, 'Nenhum objeto depende diretamente disso.')}</div>
      <div><h3 class="impacto-titulo">${icone('triangle-alert')}Verificar (dependentes indiretos)</h3>${lista(r.verificar, 'Nenhum dependente indireto.')}</div>
      <div><h3 class="impacto-titulo">${icone('file-code')}Linhas nos scripts do repositório</h3>
        ${linhas || '<p class="legenda">Nenhuma ocorrência encontrada.</p>'}</div>
      <div><h3 class="impacto-titulo">${icone('terminal')}SQL sugerido</h3>${blocoCodigo(r.sql, 'Revise antes de executar')}</div>
    </div>`;
  }

  // Aplica o que veio na URL; só recalcula se algo mudou.
  function aplicarLink(parametro) {
    const [objeto, mudanca = '', coluna = '', novo = ''] = (parametro ?? '').split('/');
    const obj = porNome.get(objeto);
    if (!obj) return;
    const mudancaValida = mudancasPara(obj).includes(mudanca) ? mudanca : '';
    const colunaValida = MUDANCAS[mudancaValida]?.coluna && obj.colunas.some((c) => c.nome === coluna) ? coluna : '';
    const mudou = objeto !== estado.objeto || mudancaValida !== estado.mudanca
      || colunaValida !== estado.coluna || (mudancaValida && novo !== estado.novo);
    if (!mudou || (!mudancaValida && objeto === estado.objeto)) return;
    estado = { objeto, mudanca: mudancaValida, coluna: colunaValida, novo: mudancaValida ? novo : '', resultado: null };
    if (mudancaValida && (!MUDANCAS[mudancaValida].coluna || colunaValida)) estado.resultado = analisar();
  }

  function render(parametro) {
    aplicarLink(parametro);
    return `${cabecalho({ secao: 'Ferramentas', titulo: 'Análise de Impacto', subtitulo: 'Simule uma mudança antes de tocar no código e veja o raio de efeito: objetos que quebram, dependentes indiretos e as linhas exatas dos scripts.' })}
      <div class="impacto">
        <section class="cartao"><h2>Simular mudança</h2><div id="impacto-form">${formulario()}</div></section>
        <section class="cartao" id="impacto-resultado" aria-live="polite">${resultado()}</section>
      </div>`;
  }

  document.addEventListener('input', (evento) => {
    const campo = evento.target.dataset?.impactoCampo;
    if (!campo) return;
    estado[campo] = evento.target.value;
    if (campo === 'objeto') Object.assign(estado, { mudanca: '', coluna: '', novo: '' });
    if (campo === 'mudanca') Object.assign(estado, { coluna: '', novo: '' });
    if (campo === 'novo') return;
    // Os campos seguintes dependem do escolhido: redesenha só o formulário.
    const form = document.getElementById('impacto-form');
    if (form) form.innerHTML = formulario();
    document.querySelector(`[data-impacto-campo="${campo}"]`)?.focus();
  });

  document.addEventListener('submit', (evento) => {
    if (evento.target.id !== 'form-impacto') return;
    evento.preventDefault();
    estado.resultado = analisar();
    // A URL vira o link da análise, para compartilhar (sem recarregar a página).
    const partes = [estado.objeto, estado.mudanca, MUDANCAS[estado.mudanca]?.coluna ? estado.coluna : '', estado.novo.trim()];
    while (partes.length && !partes.at(-1)) partes.pop();
    history.replaceState(null, '', `#/impacto/${partes.map(encodeURIComponent).join('/')}`);
    const alvo = document.getElementById('impacto-resultado');
    if (!alvo) return;
    alvo.innerHTML = resultado();
    if (window.matchMedia('(max-width: 1100px)').matches) alvo.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });

  Q.paginas.registrar('impacto', { render, titulo: 'Análise de Impacto' });
})(window.Quimia);
