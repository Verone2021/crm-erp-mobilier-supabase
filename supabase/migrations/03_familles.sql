-- ===================================================================
-- 03_familles.sql - Familles de produits avec attributs KPI
-- ===================================================================

CREATE TABLE IF NOT EXISTS familles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL UNIQUE,
  description TEXT,
  ordre_affichage INTEGER DEFAULT 1000,
  is_active BOOLEAN DEFAULT TRUE,
  target_revenue DECIMAL(10,2),                           -- Objectif CA annuel
  commission_rate DECIMAL(5,2) DEFAULT 0,                 -- Taux de commission moyen
  launch_date DATE,                                       -- Date de lancement
  lifecycle_stage TEXT                                    -- Étape du cycle de vie
    CHECK (lifecycle_stage IN ('launch','growth','mature','decline'))
    DEFAULT 'growth',
  price_range TEXT                                        -- Segmentation prix
    CHECK (price_range IN ('budget','mid-range','premium','luxury')),
  primary_channel TEXT,                                   -- Canal principal de vente
  tags TEXT[],                                            -- Étiquettes libres
  seo_title TEXT,
  seo_description TEXT,
  marketing_priority INTEGER                              -- Priorité marketing (1-10)
    DEFAULT 5 CHECK (marketing_priority BETWEEN 1 AND 10),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE familles
  ADD CONSTRAINT chk_commission_realistic
    CHECK (commission_rate BETWEEN 0 AND 50);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_familles_active           ON familles(is_active, ordre_affichage);
CREATE INDEX IF NOT EXISTS idx_familles_lifecycle        ON familles(lifecycle_stage) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_familles_price_range      ON familles(price_range)     WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_familles_tags             ON familles USING GIN(tags);

-- Trigger updated_at
CREATE TRIGGER trg_familles_updated_at
  BEFORE UPDATE ON familles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Documentation
COMMENT ON TABLE familles IS 'Familles de produits avec KPI et métriques business';
COMMENT ON COLUMN familles.target_revenue IS 'Objectif de chiffre d’affaires annuel';
COMMENT ON COLUMN familles.lifecycle_stage IS 'Étape du cycle de vie pour stratégie marketing';

