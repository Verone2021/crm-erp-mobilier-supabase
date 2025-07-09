-- 02_user_profiles.sql
-- Migration: 20250630000005_create_user_profiles.sql
-- Description: Profils utilisateurs pour CRM mobilier
-- Auteur: Assistant IA CRM/ERP
-- Date: 2025-06-30

-- (1) Fonction trigger générique pour mettre à jour updated_at
-- Si vous l'avez déjà appliquée, vous pouvez commenter ou supprimer ce bloc
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_updated_at_column() 
  IS 'Met à jour automatiquement le champ updated_at avant chaque modification';

-- (2) Table user_profiles
CREATE TABLE IF NOT EXISTS user_profiles (
  id UUID PRIMARY KEY
    REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Identité
  first_name       TEXT,
  last_name        TEXT,
  company_name     TEXT,
  phone            TEXT,
  
  -- Préférences
  language         CHAR(2)   DEFAULT 'fr',
  currency         CHAR(3)   DEFAULT 'EUR',
  timezone         TEXT      DEFAULT 'Europe/Paris',
  
  -- CRM métier
  customer_type    TEXT      NOT NULL
    CHECK (customer_type IN ('individual','business'))
    DEFAULT 'individual',
  preferred_contact TEXT     NOT NULL
    CHECK (preferred_contact IN ('email','phone','whatsapp'))
    DEFAULT 'email',
  marketing_consent BOOLEAN   DEFAULT FALSE,
  
  -- Adresse livraison
  street_address   TEXT,
  city             TEXT,
  postal_code      TEXT,
  country          CHAR(2)   DEFAULT 'FR',
  
  -- Onboarding
  profile_completed        BOOLEAN        DEFAULT FALSE,
  onboarding_completed_at  TIMESTAMPTZ,
  
  -- Métadonnées CRM
  notes            TEXT,
  tags             TEXT[],
  
  -- Timestamps
  created_at       TIMESTAMPTZ   DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   DEFAULT NOW()
);

-- (3) Contraintes complémentaires
ALTER TABLE user_profiles 
  ADD CONSTRAINT chk_phone_format 
    CHECK (phone IS NULL OR phone ~ '^[\+]?[0-9\s\-\(\)\.]{10,20}$');

ALTER TABLE user_profiles
  ADD CONSTRAINT chk_onboarding_date
    CHECK (
      (profile_completed = FALSE AND onboarding_completed_at IS NULL)
      OR
      (profile_completed = TRUE)
    );

-- (4) Index pour les usages fréquents
CREATE INDEX ON user_profiles(customer_type);
CREATE INDEX ON user_profiles(country);
CREATE INDEX ON user_profiles(profile_completed);
CREATE INDEX ON user_profiles(customer_type, profile_completed)
  WHERE customer_type = 'business';
CREATE INDEX ON user_profiles(marketing_consent, preferred_contact)
  WHERE marketing_consent = TRUE;

-- (5) Trigger pour updated_at
CREATE TRIGGER trg_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- (6) Activer Row Level Security
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- (7) Politiques RLS
CREATE POLICY "Users can view own profile"
  ON user_profiles
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can create own profile"
  ON user_profiles
  FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON user_profiles
  FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Admins can manage all profiles"
  ON user_profiles
  FOR ALL
  USING (
    (auth.jwt() ->> 'role') = 'admin'
    OR
    EXISTS (
      SELECT 1 FROM user_profiles
       WHERE id = auth.uid()
         AND 'admin' = ANY(tags)
    )
  );

-- (8) Vue enrichie pour l'interface CRM
CREATE OR REPLACE VIEW users_complete AS
SELECT 
  au.id,
  au.email,
  au.created_at AS signup_date,
  au.last_sign_in_at AS last_login,
  au.email_confirmed_at IS NOT NULL AS email_verified,
  
  up.first_name,
  up.last_name,
  up.company_name,
  up.phone,
  up.customer_type,
  up.preferred_contact,
  up.country,
  up.city,
  up.profile_completed,
  up.marketing_consent,
  up.tags,
  up.notes,
  up.created_at AS profile_created_at,
  up.updated_at AS profile_updated_at,
  
  CONCAT(
    COALESCE(up.first_name,''), ' ',
    COALESCE(up.last_name,'')
  ) AS full_name,
  
  CASE 
    WHEN up.company_name IS NOT NULL
         AND up.customer_type = 'business'
    THEN up.company_name
    ELSE CONCAT(
      COALESCE(up.first_name,''), ' ',
      COALESCE(up.last_name,'')
    )
  END AS display_name,
  
  (au.last_sign_in_at > NOW() - INTERVAL '30 days') AS recently_active,
  (au.last_sign_in_at > NOW() - INTERVAL '7 days')  AS active_this_week,
  
  (up.profile_completed 
   AND au.email_confirmed_at IS NOT NULL) AS fully_onboarded,
  
  CASE 
    WHEN up.street_address IS NOT NULL 
         AND up.city IS NOT NULL 
    THEN 
      CONCAT(
        up.street_address, ', ',
        up.city,
        COALESCE(' '||up.postal_code,''),
        COALESCE(', '||up.country,'')
      )
    ELSE NULL
  END AS full_address,
  
  ('admin' = ANY(COALESCE(up.tags, ARRAY[]::TEXT[]))) AS is_admin,
  ('vip'   = ANY(COALESCE(up.tags, ARRAY[]::TEXT[]))) AS is_vip,
  (up.customer_type = 'business' 
   AND up.company_name IS NOT NULL) AS is_business_complete

FROM auth.users au
LEFT JOIN user_profiles up 
  ON au.id = up.id
WHERE au.deleted_at IS NULL;

-- (9) Fonction de statistiques utilisateur
CREATE OR REPLACE FUNCTION get_user_stats()
RETURNS TABLE(
  total_users         BIGINT,
  individual_customers BIGINT,
  business_customers  BIGINT,
  completed_profiles  BIGINT,
  active_last_30d     BIGINT,
  countries_count     BIGINT
)
LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COUNT(*) FILTER (WHERE au.deleted_at IS NULL),
    COUNT(*) FILTER (WHERE up.customer_type = 'individual'),
    COUNT(*) FILTER (WHERE up.customer_type = 'business'),
    COUNT(*) FILTER (WHERE up.profile_completed),
    COUNT(*) FILTER (WHERE au.last_sign_in_at > NOW() - INTERVAL '30 days'),
    COUNT(DISTINCT up.country)
  FROM auth.users au
  LEFT JOIN user_profiles up ON au.id = up.id;
END;
$$;

COMMENT ON VIEW users_complete IS 'Combinaison de auth.users + user_profiles avec champs calculés et indicateurs';
COMMENT ON FUNCTION get_user_stats IS 'Retourne les KPIs clés sur vos utilisateurs du CRM';

