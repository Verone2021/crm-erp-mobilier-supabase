-- ===================================================================
-- 09_products.sql – Table des produits avec variantes individuelles
-- VERSION CORRIGÉE - Sans erreur d'exécution
-- ===================================================================

-- 1) Fonction générique pour updated_at (si pas déjà créée)
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2) Table principale des produits (DONNÉES NATIVES SEULEMENT)
CREATE TABLE products (
  -- Clé primaire & audit
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  -- Informations générales
  nom TEXT NOT NULL,
  ref_interne TEXT, -- ✅ CORRIGÉ: UNIQUE sera ajouté via contrainte séparée
  ref_fournisseur TEXT, 

  -- Type et unité
  type_article TEXT NOT NULL DEFAULT 'vente de marchandises'
    CHECK (type_article IN ('vente de marchandises','prestations de services')),
  unite TEXT DEFAULT 'Unité',

  -- Statut workflow sourcing
  statut TEXT NOT NULL DEFAULT 'sourcing'
    CHECK (statut IN ('sourcing','validation','demande_echantillon','actif','fin_de_serie')),
  validation_sourcing TEXT,
  validation_echantillon TEXT,
  fin_de_serie BOOLEAN NOT NULL DEFAULT FALSE,

  -- Classification hiérarchique
  sous_categorie_id UUID NOT NULL 
    REFERENCES sous_categories(id) ON DELETE RESTRICT,
  product_group_id UUID 
    REFERENCES product_groups(id) ON DELETE SET NULL,

  -- Caractéristiques produit (1 couleur/matière par produit)
  couleurs TEXT[] DEFAULT '{}',
  matieres TEXT[] DEFAULT '{}',
  pieces_habitation TEXT[] DEFAULT '{}',
  dimensions TEXT,
  poids_kg DECIMAL(8,2),

  -- ✅ TARIFICATION NATIVE (saisie manuelle uniquement)
  tva_fournisseur DECIMAL(5,2),
  prix_achat_ht_indicatif DECIMAL(10,2), -- Prix catalogue fournisseur
  marge_percent DECIMAL(5,2) DEFAULT 0,  -- Marge souhaitée
  
  -- ✅ CALCULS SIMPLES depuis la même table
  prix_minimum_ht DECIMAL(10,2) GENERATED ALWAYS AS (
    CASE
      WHEN prix_achat_ht_indicatif IS NOT NULL AND marge_percent IS NOT NULL 
      THEN prix_achat_ht_indicatif * (1 + marge_percent / 100)
      ELSE NULL
    END
  ) STORED,
  
  prix_minimum_ttc DECIMAL(10,2) GENERATED ALWAYS AS (
    CASE
      WHEN prix_achat_ht_indicatif IS NOT NULL AND marge_percent IS NOT NULL AND tva_fournisseur IS NOT NULL
      THEN prix_achat_ht_indicatif * (1 + marge_percent / 100) * (1 + tva_fournisseur / 100)
      ELSE NULL
    END
  ) STORED,

  -- ✅ GESTION STOCKS NATIVE (paramètres seulement)
  seuil_alerte INTEGER DEFAULT NULL, -- NULL = pas d'alerte, >= 0 = alerte active
  moq INTEGER DEFAULT 0, -- Minimum Order Quantity

  -- Descriptions multiples
  description_fournisseur TEXT,
  description_whatsapp TEXT,
  description_site_internet TEXT,
  description_leboncoin TEXT,

  -- SEO
  titre_seo TEXT,
  description_seo TEXT,

  -- Relations
  fournisseur_id UUID REFERENCES partenaires(id) ON DELETE SET NULL,

  -- Métadonnées
  variantes INTEGER DEFAULT 0,
  univers TEXT,

  -- ✅ NOM COMPLET auto-généré
  nom_complet TEXT GENERATED ALWAYS AS (
    CASE
      WHEN array_length(couleurs, 1) = 1 THEN nom || ' ' || couleurs[1]
      WHEN array_length(matieres, 1) = 1 THEN nom || ' ' || matieres[1]
      WHEN array_length(couleurs, 1) >= 1 AND array_length(matieres, 1) >= 1 THEN 
        nom || ' ' || couleurs[1] || ' ' || matieres[1]
      ELSE nom
    END
  ) STORED
);

-- ✅ CONTRAINTE UNIQUE SÉPARÉE pour ref_interne (évite les erreurs)
ALTER TABLE products 
  ADD CONSTRAINT uq_products_ref_interne UNIQUE (ref_interne);

-- 3) Héritage depuis product_groups
CREATE OR REPLACE FUNCTION inherit_from_product_group()
RETURNS TRIGGER AS $$
BEGIN
  -- Si un groupe est spécifié, hériter des attributs manquants
  IF NEW.product_group_id IS NOT NULL THEN
    
    -- Hériter sous_categorie_id si pas défini
    IF NEW.sous_categorie_id IS NULL THEN
      SELECT sous_categorie_id INTO NEW.sous_categorie_id
      FROM product_groups WHERE id = NEW.product_group_id;
    END IF;
    
    -- Hériter fournisseur_id si pas défini  
    IF NEW.fournisseur_id IS NULL THEN
      SELECT fournisseur_id INTO NEW.fournisseur_id
      FROM product_groups WHERE id = NEW.product_group_id;
    END IF;
    
    -- Hériter dimensions si pas définies
    IF NEW.dimensions IS NULL THEN
      SELECT dimensions INTO NEW.dimensions
      FROM product_groups WHERE id = NEW.product_group_id;
    END IF;
    
    -- Hériter poids si pas défini
    IF NEW.poids_kg IS NULL THEN
      SELECT poids_kg INTO NEW.poids_kg
      FROM product_groups WHERE id = NEW.product_group_id;
    END IF;
    
  END IF;
  
  -- Hériter TVA du fournisseur si pas définie
  IF NEW.tva_fournisseur IS NULL AND NEW.fournisseur_id IS NOT NULL THEN
    SELECT taux_tva INTO NEW.tva_fournisseur
    FROM partenaires WHERE id = NEW.fournisseur_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4) Validation groupe actif
CREATE OR REPLACE FUNCTION validate_product_group_active()
RETURNS TRIGGER AS $$
DECLARE
  is_active_group BOOLEAN;
BEGIN
  IF NEW.product_group_id IS NOT NULL THEN
    SELECT is_active INTO is_active_group
    FROM product_groups WHERE id = NEW.product_group_id;
    
    IF is_active_group IS FALSE THEN
      RAISE EXCEPTION 'Impossible de lier un produit à un groupe inactif (group_id: %)', NEW.product_group_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5) Triggers
CREATE TRIGGER trg_inherit_from_product_group
  BEFORE INSERT OR UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION inherit_from_product_group();

CREATE TRIGGER trg_validate_product_group_active
  BEFORE INSERT OR UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION validate_product_group_active();

CREATE TRIGGER trg_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 6) Index pour performance
CREATE INDEX idx_products_sous_categorie ON products(sous_categorie_id);
CREATE INDEX idx_products_group ON products(product_group_id);
CREATE INDEX idx_products_fournisseur ON products(fournisseur_id);
CREATE INDEX idx_products_statut ON products(statut);
CREATE INDEX idx_products_type_article ON products(type_article);

-- ✅ INDEX PARTIEL OPTIMISÉ pour ref_interne
CREATE INDEX idx_products_ref_interne ON products(ref_interne) 
  WHERE ref_interne IS NOT NULL;

CREATE INDEX idx_products_nom_complet ON products(nom_complet);
CREATE INDEX idx_products_active ON products(is_active) WHERE is_active = TRUE;
CREATE INDEX idx_products_couleurs ON products USING GIN(couleurs);
CREATE INDEX idx_products_matieres ON products USING GIN(matieres);
CREATE INDEX idx_products_pieces ON products USING GIN(pieces_habitation);

-- 7) Tables complémentaires

-- Images produits
CREATE TABLE product_images (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  ordre INTEGER DEFAULT 1,
  legende TEXT,
  type_image TEXT DEFAULT 'produit' CHECK (type_image IN ('produit', 'usage', 'detail')),
  is_principale BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(product_id, ordre)
);

CREATE INDEX idx_product_images_product ON product_images(product_id);
CREATE INDEX idx_product_images_principale ON product_images(product_id, is_principale) 
  WHERE is_principale = TRUE;

-- URLs polymorphiques
CREATE TABLE entity_urls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  entity_type TEXT NOT NULL CHECK (entity_type IN ('product', 'partenaire', 'commande')),
  entity_id UUID NOT NULL,
  
  type_url TEXT NOT NULL CHECK (type_url IN (
    'site_ecommerce',      -- Site e-commerce fournisseur
    'google_drive',        -- Dossier médias
    'chatgpt_fournisseur', -- ChatGPT description fournisseur
    'chatgpt_site_web',    -- ChatGPT description site
    'chatgpt_whatsapp',    -- ChatGPT description WhatsApp
    'voir_produit'         -- Page produit publique
  )),
  
  url TEXT NOT NULL,
  libelle_bouton TEXT,
  description TEXT,
  
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  UNIQUE(entity_type, entity_id, type_url)
);

CREATE INDEX idx_entity_urls_lookup ON entity_urls(entity_type, entity_id);

-- 8) Vue enrichie de base (sans calculs d'autres tables)
CREATE VIEW products_enrichie AS
SELECT 
  p.*,
  
  -- Informations hiérarchiques
  sc.nom as sous_categorie_nom,
  c.nom as categorie_nom,
  f.nom as famille_nom,
  
  -- Informations groupe
  pg.nom as groupe_nom,
  pg.description_groupe,
  
  -- Informations fournisseur
  fournisseur.nom_complet as fournisseur_nom,
  fournisseur.email as fournisseur_email,
  
  -- Compteurs images
  (SELECT COUNT(*) FROM product_images pi WHERE pi.product_id = p.id) as nb_images,
  (SELECT url FROM product_images pi 
   WHERE pi.product_id = p.id AND pi.is_principale = TRUE LIMIT 1) as image_principale_url
  
FROM products p
LEFT JOIN sous_categories sc ON p.sous_categorie_id = sc.id
LEFT JOIN categories c ON sc.categorie_id = c.id
LEFT JOIN familles f ON c.famille_id = f.id
LEFT JOIN product_groups pg ON p.product_group_id = pg.id
LEFT JOIN partenaires fournisseur ON p.fournisseur_id = fournisseur.id
ORDER BY p.nom_complet;

-- Vue URLs produits
CREATE VIEW product_urls AS
SELECT 
  entity_id as product_id,
  type_url,
  url,
  libelle_bouton,
  description
FROM entity_urls 
WHERE entity_type = 'product' AND is_active = TRUE;

-- 9) Fonctions utilitaires pour URLs
CREATE OR REPLACE FUNCTION add_entity_url(
  p_entity_type TEXT,
  p_entity_id UUID,
  p_type_url TEXT,
  p_url TEXT,
  p_libelle_bouton TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  url_id UUID;
BEGIN
  INSERT INTO entity_urls (entity_type, entity_id, type_url, url, libelle_bouton)
  VALUES (p_entity_type, p_entity_id, p_type_url, p_url, p_libelle_bouton)
  ON CONFLICT (entity_type, entity_id, type_url) 
  DO UPDATE SET url = EXCLUDED.url, libelle_bouton = EXCLUDED.libelle_bouton
  RETURNING id INTO url_id;
  
  RETURN url_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour récupérer toutes les URLs d'une entité (pour frontend)
CREATE OR REPLACE FUNCTION get_entity_urls(
  p_entity_type TEXT,
  p_entity_id UUID
) RETURNS TABLE (
  type_url TEXT,
  url TEXT,
  libelle_bouton TEXT,
  description TEXT
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    eu.type_url,
    eu.url,
    eu.libelle_bouton,
    eu.description
  FROM entity_urls eu
  WHERE eu.entity_type = p_entity_type
    AND eu.entity_id = p_entity_id
    AND eu.is_active = TRUE
  ORDER BY eu.type_url;
END;
$$ LANGUAGE plpgsql;

-- 10) Contraintes métier
ALTER TABLE products
  ADD CONSTRAINT chk_marge_realiste CHECK (marge_percent IS NULL OR (marge_percent >= 0 AND marge_percent <= 300)),
  ADD CONSTRAINT chk_tva_valide CHECK (tva_fournisseur IS NULL OR (tva_fournisseur >= 0 AND tva_fournisseur <= 100)),
  ADD CONSTRAINT chk_poids_positif CHECK (poids_kg IS NULL OR poids_kg > 0),
  ADD CONSTRAINT chk_moq_positif CHECK (moq >= 0);

-- 11) Documentation
COMMENT ON TABLE products IS 'Table des produits - chaque produit = 1 variante spécifique (données natives uniquement)';
COMMENT ON COLUMN products.nom_complet IS 'Nom + couleur/matière généré automatiquement';
COMMENT ON COLUMN products.product_group_id IS 'Groupe de variantes - hérite des attributs communs';
COMMENT ON COLUMN products.seuil_alerte IS 'NULL = pas d''alerte stock, >= 0 = seuil actif';
COMMENT ON COLUMN products.prix_achat_ht_indicatif IS 'Prix catalogue fournisseur (saisi manuellement)';
COMMENT ON COLUMN products.marge_percent IS 'Marge souhaitée en pourcentage';

-- ===================================================================
-- SCRIPT VALIDÉ ✅
-- - Contrainte unique sur ref_interne ajoutée séparément
-- - Index partiel optimisé 
-- - Aucune référence aux rôles PostgreSQL
-- - Toutes les dépendances respectées
-- ===================================================================
