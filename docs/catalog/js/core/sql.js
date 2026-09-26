/* Quimia · núcleo — realce de SQL e bloco de código com numeração de linhas. */
(function (Q) {
  'use strict';
  if (!Q) return;
  const { esc, icone } = Q.util;

  const PALAVRAS = /\b(CREATE|OR|REPLACE|TABLE|VIEW|FUNCTION|PROCEDURE|TRIGGER|INDEX|UNIQUE|IF|NOT|EXISTS|ON|AS|SELECT|FROM|JOIN|LEFT|INNER|WHERE|GROUP|BY|ORDER|WITH|RETURNS|RETURN|LANGUAGE|BEGIN|END|DECLARE|INSERT|INTO|VALUES|UPDATE|SET|DELETE|DROP|ALTER|ADD|PRIMARY|KEY|FOREIGN|REFERENCES|CHECK|DEFAULT|NULL|CONSTRAINT|GENERATED|ALWAYS|IDENTITY|AFTER|BEFORE|FOR|EACH|ROW|EXECUTE|AND|IN|IS|CASE|WHEN|THEN|ELSE|DISTINCT|OVER|PARTITION|UNION|ALL|LIMIT|LOOP|RAISE|EXCEPTION|PERFORM|QUERY|COMMENT|CASCADE|TRUNCATE|COPY|COLUMN)\b/g;

  function destacarSql(sql) {
    // Strings e comentários primeiro, para não colorir palavras dentro deles.
    // $$ ... $$ é corpo de função (código) e continua destacado; só o
    // dollar-quote com tag ($c$ ... $c$) é string literal.
    return sql.split(/('(?:[^']|'')*'|--[^\n]*|\$[A-Za-z_]\w*\$[\s\S]*?\$[A-Za-z_]\w*\$)/g).map((parte, i) => {
      if (i % 2 === 1) return `<span class="${parte.startsWith('--') ? 'sql-com' : 'sql-str'}">${esc(parte)}</span>`;
      return esc(parte).replace(PALAVRAS, '<span class="sql-kw">$1</span>');
    }).join('');
  }

  // linhaDestaque (opcional) pinta a linha indicada, usado pelos links da Análise de Impacto.
  function blocoCodigo(sql, rotulo, linhaDestaque) {
    const texto = sql.replace(/\s+$/, '');
    const total = texto.split('\n').length;
    const numeros = Array.from({ length: total }, (_, i) => i + 1).join('\n');
    const destaque = linhaDestaque >= 1 && linhaDestaque <= total
      ? `<div class="linha-destaque" style="top:calc(16px + ${linhaDestaque - 1} * 1.6em)" aria-hidden="true"></div>` : '';
    return `<div class="codigo">
      <div class="codigo-barra"><span>${esc(rotulo)}</span>
        <button class="botao" data-acao="copiar">${icone('copy')}Copiar</button></div>
      <div class="codigo-corpo">${destaque}<pre class="codigo-numeros" aria-hidden="true">${numeros}</pre><pre class="codigo-texto"><code>${destacarSql(texto)}</code></pre></div>
    </div>`;
  }

  Q.util.destacarSql = destacarSql;
  Q.ui.blocoCodigo = blocoCodigo;
})(window.Quimia);
