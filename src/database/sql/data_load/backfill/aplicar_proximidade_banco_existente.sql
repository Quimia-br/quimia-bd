-- Aplica no banco JÁ EXISTENTE as mudanças de Proximidade (lat/long em ponto_parceiro e
-- tabela ponto_salvo), sem recriar nada e sem tocar em usuario. Alternativa ao setup_data,
-- que recria o banco inteiro. Seguro para rodar mais de uma vez; tudo ou nada (transação).
-- Depois, rodar geocode_ponto_parceiro.sql para preencher os pontos sem coordenada.

BEGIN;

ALTER TABLE ponto_parceiro
    ADD COLUMN IF NOT EXISTS latitude  NUMERIC(9,6),
    ADD COLUMN IF NOT EXISTS longitude NUMERIC(9,6);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ponto_latitude') THEN
        ALTER TABLE ponto_parceiro ADD CONSTRAINT chk_ponto_latitude CHECK (latitude BETWEEN -90 AND 90);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ponto_longitude') THEN
        ALTER TABLE ponto_parceiro ADD CONSTRAINT chk_ponto_longitude CHECK (longitude BETWEEN -180 AND 180);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_ponto_coordenadas_juntas') THEN
        ALTER TABLE ponto_parceiro ADD CONSTRAINT chk_ponto_coordenadas_juntas CHECK ((latitude IS NULL) = (longitude IS NULL));
    END IF;
END $$;

COMMENT ON COLUMN ponto_parceiro.latitude  IS 'Latitude do ponto em graus decimais (-90 a 90). Opcional; só vale junto com longitude.';
COMMENT ON COLUMN ponto_parceiro.longitude IS 'Longitude do ponto em graus decimais (-180 a 180). Opcional; só vale junto com latitude.';

CREATE TABLE IF NOT EXISTS ponto_salvo (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_usuario UUID NOT NULL,
    id_ponto   INTEGER NOT NULL,
    criado_em  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ponto_salvo_unique UNIQUE (id_usuario, id_ponto)
);

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ponto_salvo_usuario') THEN
        ALTER TABLE ponto_salvo ADD CONSTRAINT fk_ponto_salvo_usuario
            FOREIGN KEY (id_usuario) REFERENCES usuario(id) ON DELETE CASCADE;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_ponto_salvo_ponto') THEN
        ALTER TABLE ponto_salvo ADD CONSTRAINT fk_ponto_salvo_ponto
            FOREIGN KEY (id_ponto) REFERENCES ponto_parceiro(id) ON DELETE CASCADE;
    END IF;
END $$;

COMMIT;
