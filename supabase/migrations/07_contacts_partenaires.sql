-- ===================================================================
-- 07_contacts_partenaires.sql – Contacts associés aux partenaires pro (VERSION CORRIGÉE)
-- ===================================================================

-- 1) Fonction générique pour auto-update du champ updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2) Table des contacts
CREATE TABLE contacts_partenaires (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Lien vers le partenaire
  partenaire_id UUID NOT NULL REFERENCES partenaires(id) ON DELETE CASCADE,

  -- Identité du contact
  prenom TEXT NOT NULL,
  nom TEXT NOT NULL,
  civilite TEXT CHECK (civilite IN ('M.', 'Mme', 'Dr', 'Prof')),  -- optionnel

  -- Fonction et responsabilités
  fonction TEXT,
  service TEXT,
  est_contact_principal BOOLEAN NOT NULL DEFAULT FALSE,

  -- Coordonnées
  email_pro TEXT,
  telephone_direct TEXT,
  telephone_mobile TEXT,

  -- Domaines de compétence
  domaine_competence TEXT[] DEFAULT '{}',

  -- Langues parlées
  langues TEXT[] DEFAULT '{}',

  -- Disponibilité
  disponibilite TEXT,
  timezone TEXT DEFAULT 'Europe/Paris',

  -- Notes et historique
  notes TEXT,
  derniere_interaction TIMESTAMPTZ,

  -- Statut
  is_active BOOLEAN NOT NULL DEFAULT TRUE,

  -- Audit
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- Nom complet auto-généré
  nom_complet TEXT GENERATED ALWAYS AS (
    COALESCE(civilite || ' ', '') ||
    initcap(prenom) || ' ' ||
    upper(nom)
  ) STORED
);

-- 3) Contraintes métier (SANS sous-requête)
ALTER TABLE contacts_partenaires
  -- Email pro valide si renseigné
  ADD CONSTRAINT chk_email_pro_format CHECK (
    email_pro IS NULL
    OR email_pro ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'
  );
  -- ✅ SUPPRIMÉ la contrainte avec sous-requête qui causait l'erreur

-- 4) Index unique partiel pour contact principal
CREATE UNIQUE INDEX unique_contact_principal
  ON contacts_partenaires(partenaire_id)
 WHERE est_contact_principal = TRUE;

-- 5) Trigger de validation : interdire les contacts pour client_particulier
-- ✅ REMPLACE la contrainte CHECK par un trigger (plus flexible)
CREATE OR REPLACE FUNCTION validate_contact_partenaire()
RETURNS TRIGGER AS $$
DECLARE
  p_type TEXT;
BEGIN
  -- Récupérer le type du partenaire
  SELECT type_partenaire INTO p_type
    FROM partenaires
   WHERE id = NEW.partenaire_id;

  -- Vérifier que le partenaire existe
  IF p_type IS NULL THEN
    RAISE EXCEPTION 'Partenaire avec ID % n''existe pas', NEW.partenaire_id;
  END IF;

  -- Interdire les contacts pour les clients particuliers
  IF p_type = 'client_particulier' THEN
    RAISE EXCEPTION
      'Impossible d''ajouter un contact pour un client particulier (ID: %, Type: %)',
      NEW.partenaire_id, p_type;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_contact_partenaire
  BEFORE INSERT OR UPDATE ON contacts_partenaires
  FOR EACH ROW EXECUTE FUNCTION validate_contact_partenaire();

-- 6) Trigger updated_at
CREATE TRIGGER trg_contacts_partenaires_updated_at
  BEFORE UPDATE ON contacts_partenaires
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 7) Fonction pour gérer automatiquement le contact principal unique
CREATE OR REPLACE FUNCTION manage_contact_principal()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.est_contact_principal THEN
    -- Désactiver les autres contacts principaux du même partenaire
    UPDATE contacts_partenaires
      SET est_contact_principal = FALSE,
          updated_at = NOW()
    WHERE partenaire_id = NEW.partenaire_id
      AND id <> NEW.id
      AND est_contact_principal = TRUE;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_manage_contact_principal
  BEFORE INSERT OR UPDATE ON contacts_partenaires
  FOR EACH ROW 
  WHEN (NEW.est_contact_principal = TRUE)
  EXECUTE FUNCTION manage_contact_principal();

-- 8) Index pour performance
CREATE INDEX idx_contacts_partenaire_id ON contacts_partenaires(partenaire_id);
CREATE INDEX idx_contacts_email         ON contacts_partenaires(email_pro)        WHERE email_pro IS NOT NULL;
CREATE INDEX idx_contacts_nom_complet   ON contacts_partenaires(nom_complet)     WHERE is_active = TRUE;
CREATE INDEX idx_contacts_competences   ON contacts_partenaires USING GIN(domaine_competence);
CREATE INDEX idx_contacts_service       ON contacts_partenaires(service)        WHERE service IS NOT NULL;

-- 9) Vues utilitaires
CREATE VIEW contacts_avec_partenaire AS
SELECT
  c.id,
  c.partenaire_id,
  p.type_partenaire,
  p.nom_complet AS partenaire_nom,
  c.nom_complet AS contact_nom,
  c.fonction,
  c.service,
  c.est_contact_principal,
  c.email_pro,
  c.telephone_direct,
  c.telephone_mobile,
  c.domaine_competence,
  c.langues,
  c.disponibilite,
  c.derniere_interaction,
  c.is_active,
  c.created_at
FROM contacts_partenaires c
JOIN partenaires p ON c.partenaire_id = p.id
WHERE c.is_active = TRUE AND p.is_active = TRUE
ORDER BY p.nom_complet, c.est_contact_principal DESC, c.nom_complet;

CREATE VIEW contacts_principaux AS
SELECT
  p.id AS partenaire_id,
  p.type_partenaire,
  p.nom_complet AS partenaire_nom,
  c.nom_complet AS contact_principal_nom,
  c.email_pro      AS contact_principal_email,
  c.telephone_direct,
  c.fonction
FROM partenaires p
LEFT JOIN contacts_partenaires c
  ON p.id = c.partenaire_id
 AND c.est_contact_principal = TRUE
 AND c.is_active = TRUE
WHERE p.is_active = TRUE
  AND p.type_partenaire IN ('client_pro','fournisseur','prestataire')
ORDER BY p.nom_complet;

-- 10) Fonction utilitaire pour récupérer le contact principal
CREATE OR REPLACE FUNCTION get_contact_principal(p_id UUID)
RETURNS TABLE(
  contact_id UUID,
  nom_complet TEXT,
  email_pro TEXT,
  telephone_direct TEXT,
  fonction TEXT
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    c.id,
    c.nom_complet,
    c.email_pro,
    c.telephone_direct,
    c.fonction
  FROM contacts_partenaires c
  WHERE c.partenaire_id = p_id
    AND c.est_contact_principal = TRUE
    AND c.is_active = TRUE;
END;
$$;

-- 11) Documentation
COMMENT ON TABLE contacts_partenaires IS
  'Contacts des partenaires pro (client_pro, fournisseur, prestataire)';
COMMENT ON COLUMN contacts_partenaires.est_contact_principal IS
  'Un seul par partenaire grâce à l''index unique partiel';
COMMENT ON COLUMN contacts_partenaires.nom_complet IS
  'Généré automatiquement, prend en compte civilité si présente';
COMMENT ON COLUMN contacts_partenaires.partenaire_id IS
  'FK vers partenaires - validation du type via trigger';

-- 12) Test d'intégrité (optionnel)
/*
-- Vérification que la validation fonctionne
DO $$
BEGIN
  -- Ceci devrait échouer si un client particulier existe
  -- INSERT INTO contacts_partenaires (partenaire_id, prenom, nom)
  -- SELECT id, 'Test', 'CONTACT' FROM partenaires WHERE type_partenaire = 'client_particulier' LIMIT 1;
  
  RAISE NOTICE 'Script contacts_partenaires exécuté avec succès';
END;
$$;
*/
