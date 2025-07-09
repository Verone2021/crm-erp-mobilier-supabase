-- ===================================================================
-- 04_categories.sql – Catégories avec métriques détaillées
-- ===================================================================

CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nom TEXT NOT NULL,
  famille_id UUID NOT NULL REFERENCES familles(id) ON DELETE CASCADE,
  description TEXT,
  ordre_affichage INTEGER DEFAULT 1000,
  is_active BOOLEAN DEFAULT TRUE,
  target_revenue       DECIMAL(10,2),                   -- Objectif CA catégorie
  target_margin_percent DECIMAL(5,2),                   -- Objectif marge %
  seasonality_factor    DECIMAL(3,2) DEFAULT 1.0        -- Facteur saisonnalité
    CHECK (seasonality_factor BETWEEN 0.1 AND 5.0),
  min_stock_days INTEGER DEFAULT 30,
  max_stock_days INTEGER DEFAULT 90,
  avg_delivery_days INTEGER DEFAULT 7,
  material_category TEXT,
  room_focus        TEXT[],
  style_category    TEXT,
  tags             TEXT[],
  is_featured      BOOLEAN DEFAULT FALSE,
  marketing_priority INTEGER DEFAULT 5
    CHECK (marketing_priority BETWEEN 1 AND 10),
  seo_title       TEXT,
  seo_description TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(famille_id, nom)
);

ALTER TABLE categories
  ADD CONSTRAINT chk_stock_days_logical
    CHECK (min_stock_days <= max_stock_days);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_categories_famille     ON categories(famille_id, is_active);
CREATE INDEX IF NOT EXISTS idx_categories_featured    ON categories(is_featured) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_categories_material    ON categories(material_category) WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_categories_style       ON categories(style_category)   WHERE is_active;
CREATE INDEX IF NOT EXISTS idx_categories_tags        ON categories USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_categories_room_focus  ON categories USING GIN(room_focus);

-- Trigger updated_at
CREATE TRIGGER trg_categories_updated_at
  BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Documentation
COMMENT ON TABLE categories IS 'Catégories avec objectifs, métriques logistiques et classification';
COMMENT ON COLUMN categories.seasonality_factor IS 'Facteur saisonnalité (0.1-5.0)';
COMMENT ON COLUMN categories.room_focus IS 'Pièces principales d’utilisation';

