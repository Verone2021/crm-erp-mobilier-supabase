-- ===================================================================
-- 05_sous_categories.sql - Sous-catégories avec tracking détaillé
-- ===================================================================

CREATE TABLE IF NOT EXISTS sous_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  categorie_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  description TEXT,
  ordre_affichage INTEGER DEFAULT 1000,
  is_active BOOLEAN DEFAULT TRUE,
  target_revenue DECIMAL(10,2),                         -- Objectif CA sous-catégorie
  conversion_rate_target DECIMAL(5,2)                   -- Objectif taux de conversion %
    CHECK (conversion_rate_target BETWEEN 0 AND 100),
  avg_unit_cost DECIMAL(10,2),
  avg_selling_price DECIMAL(10,2),
  standard_margin_percent DECIMAL(5,2)                  -- Marge standard
    CHECK (standard_margin_percent >= 0),
  size_category TEXT                                    -- Taille (small/medium/large/xl)
    CHECK (size_category IN ('small','medium','large','xl')),
  complexity_level TEXT DEFAULT 'standard'               -- Complexité
    CHECK (complexity_level IN ('simple','standard','complex')),
  customization_available BOOLEAN DEFAULT FALSE,
  reorder_threshold INTEGER DEFAULT 10,
  reorder_quantity  INTEGER DEFAULT 50,
  storage_requirements TEXT,
  tags TEXT[],
  is_bestseller BOOLEAN DEFAULT FALSE,
  is_seasonal BOOLEAN DEFAULT FALSE,
  season_peak_months INTEGER[],                         -- [1..12]
  page_views_target INTEGER,
  search_keywords TEXT[],
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(categorie_id, nom)
);

-- Contraintes métier
ALTER TABLE sous_categories
  ADD CONSTRAINT chk_valid_months
    CHECK (
      season_peak_months IS NULL
      OR season_peak_months <@ ARRAY[1,2,3,4,5,6,7,8,9,10,11,12]::INTEGER[]
    ),
  ADD CONSTRAINT chk_prices_logical
    CHECK (
      avg_unit_cost IS NULL 
      OR avg_selling_price IS NULL 
      OR avg_unit_cost <= avg_selling_price
    );

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sous_categories_categorie ON sous_categories(categorie_id, is_active);
CREATE INDEX IF NOT EXISTS idx_sous_categories_bestseller ON sous_categories(is_bestseller) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_sous_categories_seasonal ON sous_categories(is_seasonal) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_sous_categories_size ON sous_categories(size_category) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_sous_categories_tags ON sous_categories USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_sous_categories_keywords ON sous_categories USING GIN(search_keywords);

-- Trigger updated_at
CREATE TRIGGER trg_sous_categories_updated_at
  BEFORE UPDATE ON sous_categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Documentation
COMMENT ON TABLE sous_categories IS 'Sous-catégories avec KPI, stock et analytics';
COMMENT ON COLUMN sous_categories.season_peak_months IS 'Mois de pic saisonnier (1-12)';
COMMENT ON COLUMN sous_categories.search_keywords IS 'Mots-clés SEO principaux';

