CREATE TABLE log_rpa_execucao (
    id SERIAL PRIMARY KEY,
    nome_processo VARCHAR(100) NOT NULL,
    iniciado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
    finalizado_em TIMESTAMPTZ,
    status VARCHAR(20) NOT NULL CHECK (status IN ('rodando', 'sucesso', 'falha')),
    linhas_processadas INTEGER,
    mensagem_erro TEXT,
    ultimo_watermark TIMESTAMPTZ
);