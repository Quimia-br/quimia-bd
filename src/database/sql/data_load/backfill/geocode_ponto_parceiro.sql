-- Aproximação de latitude/longitude dos pontos_parceiro já existentes, pela UF.
-- Coordenada = capital da UF + desvio determinístico de até ±0.25° (mesmo critério de
-- CENTROS_UF em generate_localizacao_usuario.py). NÃO é geocodificação real: serve para
-- a busca por raio ter o que retornar. Só toca pontos sem coordenada e com UF válida;
-- seguro para rodar mais de uma vez.
-- Não entra no setup_data: o gerador já cria os pontos com coordenadas. Rodar à mão no banco existente.

WITH centro(uf, lat, lon) AS (VALUES
    ('AC', -9.97, -67.81), ('AL', -9.67, -35.74), ('AP', 0.03, -51.07),
    ('AM', -3.12, -60.02), ('BA', -12.97, -38.51), ('CE', -3.73, -38.52),
    ('DF', -15.78, -47.93), ('ES', -20.32, -40.34), ('GO', -16.68, -49.25),
    ('MA', -2.53, -44.30), ('MT', -15.60, -56.10), ('MS', -20.47, -54.62),
    ('MG', -19.92, -43.94), ('PA', -1.46, -48.50), ('PB', -7.12, -34.86),
    ('PR', -25.43, -49.27), ('PE', -8.05, -34.88), ('PI', -5.09, -42.80),
    ('RJ', -22.91, -43.17), ('RN', -5.79, -35.21), ('RS', -30.03, -51.23),
    ('RO', -8.76, -63.90), ('RR', 2.82, -60.67), ('SC', -27.59, -48.55),
    ('SP', -23.55, -46.63), ('SE', -10.91, -37.07), ('TO', -10.18, -48.33)
)
UPDATE ponto_parceiro p
   SET latitude  = round((c.lat + ((('x' || substr(md5(p.id::text || 'lat'), 1, 6))::bit(24)::int / 16777215.0) - 0.5) * 0.5)::numeric, 6),
       longitude = round((c.lon + ((('x' || substr(md5(p.id::text || 'lon'), 1, 6))::bit(24)::int / 16777215.0) - 0.5) * 0.5)::numeric, 6)
  FROM centro c
 WHERE c.uf = upper(btrim(p.estado))
   AND p.latitude IS NULL
   AND p.longitude IS NULL;
