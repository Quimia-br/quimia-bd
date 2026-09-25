CREATE INDEX IF NOT EXISTS idx_fds_composto_id_substancia ON fds_composto (id_substancia)
    WHERE id_substancia IS NOT NULL;