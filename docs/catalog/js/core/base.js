/* Quimia · núcleo — namespace, dados, constantes e registro de páginas.
   O site abre direto do arquivo (file://), onde o navegador bloqueia `import`
   de módulos ES. Por isso cada arquivo é um <script> comum, carregado em ordem
   pelo index.html, que registra sua parte em window.Quimia. */
(function () {
  'use strict';

  const dados = window.CATALOGO;
  if (!dados) {
    document.getElementById('conteudo').innerHTML =
      '<p class="vazio">data.js não encontrado. Rode <code>python -m src.catalog_site.generate_catalog</code>.</p>';
    return; // Sem window.Quimia, os outros arquivos não fazem nada.
  }

  // Tipos de objeto: rótulos, ícone, cor e a página do menu que os lista.
  // Cores categóricas com matizes bem separadas (a paleta da marca tem 5 tons
  // de verde/ciano, indistinguíveis num ponto de 8px).
  const TIPOS = {
    tabela: { rotulo: 'Tabelas', singular: 'Tabela', icone: 'table', cor: '#0E718F', pagina: 'banco' },
    log: { rotulo: 'Tabelas de log', singular: 'Tabela de log', icone: 'clock', cor: '#7B61FF', pagina: 'logs' },
    view: { rotulo: 'Views', singular: 'View', icone: 'eye', cor: '#1EEE97', pagina: 'views' },
    funcao: { rotulo: 'Functions', singular: 'Function', icone: 'code-xml', cor: '#02C1D6', pagina: 'functions' },
    procedure: { rotulo: 'Procedures', singular: 'Procedure', icone: 'code', cor: '#FF2B7C', pagina: 'procedures' },
    trigger: { rotulo: 'Triggers', singular: 'Trigger', icone: 'zap', cor: '#FCC368', pagina: 'triggers' },
    indice: { rotulo: 'Índices', singular: 'Índice', icone: 'arrow-down-wide-narrow', cor: '#949494', pagina: 'indices' }
  };

  // Grupos de arquivo da página Scripts (vêm da pasta, não do nome).
  const GRUPOS = {
    criacao: { rotulo: 'Criação', icone: 'table' },
    dataload: { rotulo: 'Data Load', icone: 'upload' },
    funcao: { rotulo: 'Functions', icone: 'code-xml' },
    view: { rotulo: 'Views', icone: 'eye' },
    procedure: { rotulo: 'Procedures', icone: 'code' },
    indice: { rotulo: 'Índices', icone: 'arrow-down-wide-narrow' },
    trigger: { rotulo: 'Triggers', icone: 'zap' },
    log: { rotulo: 'Log Tables', icone: 'clock' }
  };

  const NIVEIS = {
    publico: { rotulo: 'Público', texto: 'Pode aparecer no app e nos dashboards sem restrição.' },
    interno: { rotulo: 'Interno', texto: 'Uso da equipe e das empresas parceiras, sem dado pessoal.' },
    restrito: { rotulo: 'Restrito', texto: 'Contém dado pessoal ou sensível (LGPD).' }
  };

  const DOMINIOS = ['cadastro', 'fds', 'curadoria', 'interacao', 'auditoria', 'dimensional', 'fato', 'catalogo'];

  // Registro de páginas. Cada rota define:
  //   render(parametro, rota) -> HTML da página
  //   aoRenderizar(parametro, rota) -> opcional, roda depois do HTML entrar na tela
  //   titulo -> texto ou função(parametro) para o <title>
  //   secaoNav(parametro) -> opcional, qual item do menu fica ativo
  const paginas = new Map();

  window.Quimia = {
    dados,
    icones: window.ICONES || {},
    TIPOS, GRUPOS, NIVEIS, DOMINIOS,
    porNome: new Map(dados.objetos.map((o) => [o.nome, o])),
    porArquivo: new Map(dados.arquivos.map((a) => [a.caminho, a])),
    conteudo: document.getElementById('conteudo'),
    util: {},
    ui: {},
    paginas: {
      registrar(rota, definicao) { paginas.set(rota, definicao); },
      obter(rota) { return paginas.get(rota); }
    }
  };
})();
