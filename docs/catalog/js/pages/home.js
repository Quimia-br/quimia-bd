/* Quimia · página Visão Geral (#/). */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, plural } = Q.util;
  const { cabecalho, seloNivel, itemArquivo } = Q.ui;
  const { dados, TIPOS, NIVEIS } = Q;

  function render() {
    const c = dados.contagens;
    const relacoes = dados.objetos.filter((o) => ['tabela', 'log', 'view'].includes(o.tipo));
    const lgpd = relacoes.flatMap((o) => (o.colunas ?? []).filter((col) => col.lgpd));
    const metricas = [
      ['tabela', 'banco'], ['log', 'logs'], ['view', 'views'], ['procedure', 'procedures'],
      ['funcao', 'functions'], ['indice', 'indices'], ['trigger', 'triggers']
    ].map(([t, rota]) => `<a class="metrica" href="#/${rota}">${icone(TIPOS[t].icone)}
        <span class="metrica-valor">${c[t] ?? 0}</span><span class="metrica-rotulo">${esc(TIPOS[t].rotulo)}</span></a>`).join('')
      + `<a class="metrica" href="#/dataload">${icone('upload')}<span class="metrica-valor">${c.dataload ?? 0}</span><span class="metrica-rotulo">Data Loads</span></a>`
      + `<a class="metrica" href="#/lgpd">${icone('shield')}<span class="metrica-valor">${lgpd.length}</span><span class="metrica-rotulo">Colunas LGPD</span></a>`;

    const recentes = dados.arquivos.slice().sort((a, b) => b.alterado_em.localeCompare(a.alterado_em)).slice(0, 6);
    const niveis = Object.entries(NIVEIS).map(([nivel, info]) => {
      const n = relacoes.filter((o) => o.nivel_acesso === nivel).length;
      return `<div class="nivel"><div class="nivel-topo">${seloNivel(nivel)} ${plural(n, 'objeto', 'objetos')}</div><p>${esc(info.texto)}</p></div>`;
    }).join('');
    const ocorrencias = dados.avisos.length;
    const saude = ocorrencias
      ? `<ul class="avisos">${dados.avisos.map((a) => `<li>${esc(a)}</li>`).join('')}</ul>`
      : '<p class="legenda">Todos os arquivos foram processados sem avisos: cada tabela, coluna e view tem descrição e classificação.</p>';
    const gerado = new Date(dados.gerado_em).toLocaleString('pt-BR', { dateStyle: 'long', timeStyle: 'short' });

    return `${cabecalho({ secao: 'Quimia', titulo: 'Visão Geral', subtitulo: 'O mapa do banco PostgreSQL do Quimia, gerado a partir dos scripts SQL do repositório.' })}
      <section class="destaque">
        <p class="sobretitulo">O laboratório analítico</p>
        <h2>Quimia Database Workspace</h2>
        <p>Tabelas, colunas, regras de negócio e níveis de acesso. As descrições vêm dos COMMENT ON e a classificação vem do seed de classificação.</p>
        <span class="selo"><span class="ponto" style="--cor:#404040"></span>Gerado em ${esc(gerado)}${dados.commit ? ` · commit ${esc(dados.commit.hash)}` : ''}</span>
        <img class="destaque-marca" src="icons/logo-quimia-symbol.svg" width="130" height="145" alt="" aria-hidden="true">
      </section>
      <div class="metricas">${metricas}</div>
      <div class="grade-2">
        <section class="cartao">
          <div class="cartao-topo"><h2>Scripts recentes</h2><a class="botao" href="#/scripts">Explorar</a></div>
          <div class="itens">${recentes.map((a) => itemArquivo(a)).join('')}</div>
        </section>
        <section class="cartao">
          <div class="cartao-topo"><h2>Saúde da análise</h2>
            <span class="selo ${ocorrencias ? 'selo-lgpd' : 'selo-ok'}">${plural(ocorrencias, 'ocorrência', 'ocorrências')}</span></div>
          <p class="legenda" style="margin-bottom:12px">${plural(dados.arquivos.length, 'arquivo processado', 'arquivos processados')} e ${plural(dados.objetos.length, 'objeto documentado', 'objetos documentados')}.</p>
          ${saude}
        </section>
      </div>
      <section class="cartao"><h2>Níveis de acesso</h2><div class="niveis">${niveis}</div></section>`;
  }

  Q.paginas.registrar('inicio', { render });
})(window.Quimia);
