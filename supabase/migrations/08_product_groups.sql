-- ===================================================================
-- 08_product_groups.sql – Groupes de produits (attributs communs)
-- ===================================================================

-- Fonction générique pour updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Table product_groups
CREATE TABLE product_groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Nom du groupe (ex. "Chaise Luna")
  nom TEXT NOT NULL,

  -- Hiérarchie & fournisseur
  sous_categorie_id UUID NOT NULL
    REFERENCES sous_categories(id) ON DELETE SET NULL,
  fournisseur_id    UUID
    REFERENCES partenaires(id)     ON DELETE SET NULL,

  -- Attributs partagés
  dimensions       TEXT,        -- ex. "80×80×90 cm"
  poids_kg         DECIMAL(8,2),-- ex. 12.50

  -- Descriptif global
  description_groupe TEXT,      -- Notice commune au groupe

  -- Statut & audit
  is_active        BOOLEAN      DEFAULT TRUE,
  created_at       TIMESTAMPTZ  DEFAULT NOW(),
  updated_at       TIMESTAMPTZ  DEFAULT NOW()
);

-- Contraintes et index
ALTER TABLE product_groups
  ADD CONSTRAINT uq_pg_souscat_nom UNIQUE (sous_categorie_id, nom);

CREATE INDEX idx_pg_souscat      ON product_groups(sous_categorie_id);
CREATE INDEX idx_pg_fournisseur  ON product_groups(fournisseur_id);
CREATE INDEX idx_pg_active       ON product_groups(is_active);

-- Trigger pour updated_at
CREATE TRIGGER trg_pg_updated_at
  BEFORE UPDATE ON product_groups
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

