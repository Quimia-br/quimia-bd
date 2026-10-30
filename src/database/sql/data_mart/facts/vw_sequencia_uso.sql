CREATE OR REPLACE VIEW vw_sequencia_uso AS
WITH RECURSIVE dias AS (
    SELECT DISTINCT id_usuario, ocorreu_em::date AS dia
    FROM sessao_acesso
),
sequencia AS (
    SELECT d.id_usuario, d.dia AS inicio, d.dia, 1 AS dias_seguidos
    FROM dias d
    WHERE NOT EXISTS (
        SELECT 1 FROM dias v
        WHERE v.id_usuario = d.id_usuario AND v.dia = d.dia - 1
    )
    UNION ALL
    SELECT s.id_usuario, s.inicio, d.dia, s.dias_seguidos + 1
    FROM sequencia s
    JOIN dias d ON d.id_usuario = s.id_usuario AND d.dia = s.dia + 1
)
SELECT id_usuario, inicio, MAX(dia) AS fim, MAX(dias_seguidos) AS dias_seguidos
FROM sequencia
GROUP BY id_usuario, inicio;

COMMENT ON VIEW vw_sequencia_uso IS 'Sequências de dias consecutivos com acesso por usuário (fonte: sessao_acesso), calculadas com WITH RECURSIVE. Uma linha por sequência: início, fim e duração em dias.';
