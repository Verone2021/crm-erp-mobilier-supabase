-- ===================================================================
-- 06_partenaires.sql – Table Partenaires unifiée (VERSION FINALE)
-- ===================================================================

-- 1) Fonction générique pour auto-mettre à jour updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2) Table partenaires
CREATE TABLE partenaires (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Type et identification
  type_partenaire TEXT NOT NULL
    CHECK (type_partenaire IN (
      'client_particulier',
      'client_pro',
      'fournisseur',
      'prestataire'
    )),

  -- Données client particulier
  prenom TEXT,
  nom TEXT,
  sexe TEXT
    CHECK (sexe IN ('Homme','Femme')),

  -- Données pros / entreprises
  denomination_sociale TEXT,
  nom_commercial TEXT,
  siret VARCHAR(14),

  -- Coordonnées communes
  email TEXT,
  telephone TEXT,
  website_url TEXT,  

  -- Adresses de facturation
  billing_address_line1    TEXT NOT NULL,
  billing_address_line2    TEXT,
  billing_city             TEXT NOT NULL,
  billing_postal_code      TEXT NOT NULL,
  billing_country          CHAR(2) NOT NULL DEFAULT 'FR',

  -- Adresses de livraison optionnelles
  has_diff_shipping_addr   BOOLEAN   NOT NULL DEFAULT FALSE,
  shipping_address_line1   TEXT,
  shipping_address_line2   TEXT,
  shipping_city            TEXT,
  shipping_postal_code     TEXT,
  shipping_country         CHAR(2),

  -- Business / CRM
  canal_acquisition        TEXT,
  commentaires             TEXT,
  specialites              TEXT[]   DEFAULT '{}',
  segment_industrie        TEXT,
  conditions_paiement      TEXT
    CHECK (conditions_paiement IS NULL OR conditions_paiement IN (
      'immediate','net15','net30','net45','net60','net90'
    )),
  taux_tva                 DECIMAL(5,2)
    CHECK (taux_tva IS NULL OR (taux_tva >= 0 AND taux_tva <= 100)),

  -- Internationalisation / préférences
  langue                   CHAR(2)   NOT NULL DEFAULT 'fr',
  timezone                 TEXT      NOT NULL DEFAULT 'Europe/Paris',

  -- Flags & dates
  is_active                BOOLEAN   NOT NULL DEFAULT TRUE,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Nom complet auto-généré
  nom_complet TEXT GENERATED ALWAYS AS (
    CASE
      WHEN type_partenaire = 'client_particulier'
        THEN initcap(coalesce(prenom,'') || ' ' || coalesce(nom,''))
      ELSE coalesce(denomination_sociale, nom_commercial, '')
    END
  ) STORED
);

-- 3) Contraintes métier FLEXIBLES selon le type
ALTER TABLE partenaires
  ADD CONSTRAINT chk_client_particulier_fields CHECK (
    type_partenaire <> 'client_particulier'
    OR (prenom IS NOT NULL AND nom IS NOT NULL AND sexe IS NOT NULL)
  ),
  ADD CONSTRAINT chk_pro_denomination CHECK (
    type_partenaire = 'client_particulier'
    OR (denomination_sociale IS NOT NULL OR nom_commercial IS NOT NULL)
  ),
  ADD CONSTRAINT chk_email_format CHECK (
    email IS NULL 
    OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  ),
  ADD CONSTRAINT chk_shipping_coherence CHECK (
    has_diff_shipping_addr = FALSE 
    OR (
      shipping_address_line1 IS NOT NULL AND 
      shipping_city IS NOT NULL AND 
      shipping_postal_code IS NOT NULL
    )
  );

-- 4) Trigger updated_at
CREATE TRIGGER trg_partenaires_updated_at
  BEFORE UPDATE ON partenaires
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 5) Index pour performance
CREATE INDEX idx_partenaires_type_actif    ON partenaires(type_partenaire, is_active);
CREATE INDEX idx_partenaires_nom_complet   ON partenaires(nom_complet) WHERE is_active;
CREATE INDEX idx_partenaires_email         ON partenaires(email)          WHERE email IS NOT NULL;
CREATE INDEX idx_partenaires_siret         ON partenaires(siret)          WHERE siret IS NOT NULL;
CREATE INDEX idx_partenaires_canal         ON partenaires(canal_acquisition) WHERE canal_acquisition IS NOT NULL;
CREATE INDEX idx_partenaires_segment       ON partenaires(segment_industrie)  WHERE segment_industrie IS NOT NULL;
CREATE INDEX idx_partenaires_specialites   ON partenaires USING GIN(specialites);

-- 6) Vue simplifiée pour l’interface
CREATE VIEW partenaires_liste AS
SELECT
  id,
  type_partenaire,
  nom_complet,
  email,
  telephone,
  website_url,
  CASE
    WHEN has_diff_shipping_addr THEN shipping_city
    ELSE billing_city
  END AS ville_principale,
  specialites,
  segment_industrie,
  canal_acquisition,
  conditions_paiement,
  is_active,
  created_at
FROM partenaires
WHERE is_active
ORDER BY nom_complet;

-- 7) Documentation
COMMENT ON TABLE partenaires IS 'Table unifiée pour tous les partenaires (clients particuliers, clients pro, fournisseurs, prestataires)';
COMMENT ON COLUMN partenaires.type_partenaire IS 'Type: client_particulier|client_pro|fournisseur|prestataire';
COMMENT ON COLUMN partenaires.nom_complet IS 'Nom généré automatiquement selon le type';
COMMENT ON COLUMN partenaires.website_url IS 'URL du site web (pour prestataires)';
COMMENT ON COLUMN partenaires.conditions_paiement IS 'Conditions de règlement (immediate, net30, etc.)';

