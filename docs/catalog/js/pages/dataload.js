/* Quimia · página Data Load (#/dataload): scripts de seed e do pipeline de staging. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone, plural, curto, hrefArquivo } = Q.util;
  const { cabecalho, blocoCodigo, resumoCarga } = Q.ui;
  const { dados } = Q;

  // Etapas na ordem em que o setup_data.py as executa; a chave é a subpasta de data_load/.
  const ETAPAS = [
    { chave: 'seeds/', titulo: 'Seeds', texto: 'Dados curados e rotinas executadas no fim do setup.' },
    { chave: 'staging/ddl_staging/', titulo: 'Staging · estrutura', texto: 'Tabelas stg_* que recebem o CSV bruto (COPY).' },
    { chave: 'staging/validate/', titulo: 'Staging · validação', texto: 'Marca cada linha do lote como ok ou rejeitada.' },
    { chave: 'staging/migrate/', titulo: 'Staging · migração', texto: 'Insere na tabela oficial só o que ficou ok.' }
  ];

  function cartaoCarga(arquivo) {
    return `<article class="cartao carga">
      <div><p class="sobretitulo">Data Load</p><h3>${esc(arquivo.nome.replace(/\.sql$/, ''))}</h3>
        <div class="selos" style="margin-top:10px"><a class="selo selo-mono" href="${hrefArquivo(arquivo.caminho)}">${esc(curto(arquivo.caminho))}</a></div></div>
      ${resumoCarga(arquivo.carga)}
      <details class="ver-sql"><summary>${icone('file-code')}Ver SQL (${plural(arquivo.linhas, 'linha', 'linhas')})</summary>${blocoCodigo(arquivo.conteudo, arquivo.caminho)}</details>
    </article>`;
  }

  function render() {
    const cargas = dados.arquivos.filter((a) => a.grupo === 'dataload');
    const secoes = ETAPAS.map((etapa) => {
      const arquivos = cargas.filter((a) => a.caminho.includes(`/data_load/${etapa.chave}`));
      if (!arquivos.length) return '';
      return `<section class="carga-secao"><h2>${esc(etapa.titulo)} <span class="sutil" style="font-size:16px">· ${esc(etapa.texto)}</span></h2>
        <div class="grade-2">${arquivos.map(cartaoCarga).join('')}</div></section>`;
    }).join('');
    return `${cabecalho({ secao: 'Explorador', titulo: 'Data Load', subtitulo: 'Pipeline de carga do setup_data.py: TRUNCATE → COPY do CSV para stg_* → validação → migração do que ficou ok.' })}
      ${secoes}`;
  }

  Q.paginas.registrar('dataload', { render, titulo: 'Data Load' });
})(window.Quimia);
