/* Quimia · ferramenta Plano de Execução (#/plano): ordem real do setup_data.py, só leitura. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, plural, curto, hrefArquivo } = Q.util;
  const { cabecalho, chip, resumoNumeros, blocoCodigo } = Q.ui;
  const { dados, GRUPOS, porNome } = Q;

  const linkArquivo = (caminho) => (caminho
    ? `<a class="mono" href="${hrefArquivo(caminho)}">${esc(curto(caminho))}</a>` : '<span class="sutil">—</span>');

  function passoScript(p, numero) {
    const objetos = p.objetos.filter((n) => porNome.has(n));
    const mostrar = objetos.slice(0, 5);
    return `<li class="passo"><span class="passo-num">${numero}</span>
      <div class="passo-corpo"><div class="passo-topo">${linkArquivo(p.arquivo)}
        ${p.existe ? `<span class="selo">${esc(GRUPOS[p.grupo]?.rotulo ?? p.grupo)}</span>` : '<span class="selo selo-lgpd">Arquivo não existe</span>'}</div>
        ${mostrar.length ? `<div class="chips">${mostrar.map(chip).join('')}${objetos.length > 5 ? `<span class="chip">+${objetos.length - 5}</span>` : ''}</div>` : ''}
      </div></li>`;
  }

  function passoCarga(p, numero) {
    return `<li class="passo passo-carga"><span class="passo-num">${numero}</span>
      <div class="passo-corpo"><div class="passo-topo">${chip(p.tabela)}
        ${p.csv ? `<span class="selo selo-mono">${esc(curto(p.csv).replace('data_load/', ''))}</span>` : ''}
        ${p.csv_gerado ? '<span class="selo">CSV gerado em runtime</span>' : ''}</div>
        <div class="passo-fluxo"><span class="mono sutil">${esc(p.stg ?? '?')}</span>${icone('arrow-right')}${linkArquivo(p.validate)}${icone('arrow-right')}${linkArquivo(p.migrate)}</div>
      </div></li>`;
  }

  function secaoFases(plano) {
    let numero = 0; // A numeração segue a ordem de execução, atravessando as fases.
    return plano.fases.map((fase, i) => {
      const ehMart = fase.tipo === 'scripts' && fase.passos.some((p) => p.arquivo.includes('/data_mart/'));
      const titulo = fase.tipo === 'carga' ? 'Carga de dados (staging)' : ehMart ? 'Data Mart e catálogo' : 'Estrutura, rotinas e índices';
      const texto = fase.tipo === 'carga'
        ? 'Para cada tabela: TRUNCATE da stg → COPY do CSV → validação (ok/rejeitado) → migração do que ficou ok.'
        : 'executar_scripts(): cada arquivo roda inteiro, na ordem, numa única transação.';
      const passos = fase.passos.map((p) => (fase.tipo === 'carga' ? passoCarga(p, ++numero) : passoScript(p, ++numero))).join('');
      return `<section class="cartao"><div class="cartao-topo"><div><p class="sobretitulo">Fase ${i + 1}</p><h2 style="margin:0">${titulo}</h2>
          <p class="legenda">${esc(texto)}</p></div><span class="selo">${plural(fase.passos.length, 'passo', 'passos')}</span></div>
        <ol class="passos">${passos}</ol></section>`;
    }).join('');
  }

  function listaVerificacoes(plano) {
    const erros = plano.verificacoes.filter((v) => v.nivel === 'erro');
    const avisos = plano.verificacoes.filter((v) => v.nivel === 'aviso');
    return `<ul class="verificacoes">
      ${erros.length ? '' : `<li class="ok">${icone('check')}<span>Ordem validada: nenhuma view, trigger ou índice é criado antes do objeto que ele usa.</span></li>`}
      ${[...erros, ...avisos].map((v) => `<li class="${v.nivel}">${icone(v.nivel === 'erro' ? 'circle-alert' : 'triangle-alert')}<span>${esc(v.texto)}${v.arquivo ? ` <a href="${hrefArquivo(v.arquivo)}">Abrir arquivo</a>` : ''}</span></li>`).join('')}
    </ul>`;
  }

  function render() {
    const plano = dados.plano;
    if (!plano?.disponivel) {
      return `${cabecalho({ secao: 'Ferramentas', titulo: 'Plano de Execução' })}<p class="vazio">${esc(plano?.motivo ?? 'Plano indisponível.')}</p>`;
    }
    const atencao = plano.verificacoes.length;
    return `${cabecalho({ secao: 'Ferramentas', titulo: 'Plano de Execução', subtitulo: `A ordem real em que o ${esc(plano.arquivo)} cria e carrega o banco, lida direto do código. Esta página só mostra o plano: a execução continua sendo pelo terminal.` })}
      ${resumoNumeros([[plano.fases.length, 'fases'], [plano.total_scripts, 'scripts SQL'], [plano.total_cargas, 'cargas por staging'],
        [atencao, atencao === 1 ? 'ponto de atenção' : 'pontos de atenção', atencao ? 'metrica-alerta' : '']])}
      <div class="grade-2">
        <section class="cartao"><h2>Como executar</h2>
          ${blocoCodigo(plano.comando, 'Terminal, na raiz do repositório')}
          <p class="regra" style="margin-top:16px">O setup recria o banco inteiro (DROP ... CASCADE) e carrega os dados de novo. Credenciais vêm do <code>.env</code>, que nunca entra neste site.</p>
        </section>
        <section class="cartao"><h2>Verificações do plano</h2>${listaVerificacoes(plano)}</section>
      </div>
      ${secaoFases(plano)}`;
  }

  Q.paginas.registrar('plano', { render, titulo: 'Plano de Execução' });
})(window.Quimia);
