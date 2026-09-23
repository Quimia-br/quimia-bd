CREATE OR REPLACE VIEW dim_tempo AS
SELECT
    d::date AS data,
    EXTRACT(YEAR FROM d)::int AS ano,
    EXTRACT(MONTH FROM d)::int AS mes,
    EXTRACT(DAY FROM d)::int AS dia,
    TRIM(TO_CHAR(d, 'Day')) AS dia_semana,
    EXTRACT(QUARTER FROM d)::int AS trimestre,
    EXTRACT(ISODOW FROM d)::int IN (6, 7) AS fim_de_semana
FROM generate_series(
    LEAST(
        (SELECT MIN(data_consulta)::date FROM historico_recomendacao),
        (SELECT MIN(data_consulta)::date FROM historico_match)
    ),
    CURRENT_DATE,
    interval '1 day'
) AS d;