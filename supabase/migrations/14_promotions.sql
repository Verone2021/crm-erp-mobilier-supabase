/*
=============================================================================
FICHIER : 14_promotions.sql
OBJECTIF : Gestion des promotions (catalogue, client, canal, date, usage)
DÉPENDANCES : products, partenaires, commandes_client
ORDRE : Après 13_tarifs_clients_quantites.sql
=============================================================================
*/

-- ============================================
-- 1. TABLE PRINCIPALE : promotions
-- ============================================

CREATE TABLE IF NOT EXISTS promotions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code_promo TEXT UNIQUE,                         -- code promo utilisateur (optionnel)
    nom TEXT NOT NULL,                              -- nom interne
    description TEXT,
    client_id UUID REFERENCES partenaires(id) ON DELETE CASCADE, -- null = tous clients
    canal_vente TEXT DEFAULT NULL CHECK (
        canal_vente IS NULL OR 
        canal_vente IN ('etsy', 'faire', 'site_web', 'salon', 'showroom', 'email', 'telephone')
    ),                                              -- null = tous canaux
    produit_id UUID REFERENCES products(id) ON DELETE CASCADE,   -- null = tous produits
    type_promotion TEXT NOT NULL CHECK (
        type_promotion IN ('remise_valeur', 'remise_pourcentage', 'offre_speciale')
    ),
    valeur DECIMAL(10,2),                           -- montant ou pourcentage selon type
    quantite_min INTEGER DEFAULT 1 CHECK (quantite_min > 0),
    quantite_max INTEGER,                           -- null = illimité
    montant_min DECIMAL(10,2),                      -- seuil mini de commande
    montant_max DECIMAL(10,2),                      -- seuil maxi (optionnel)
    date_debut DATE NOT NULL DEFAULT CURRENT_DATE,
    date_fin DATE,
    quota_activations INTEGER,                      -- nombre d'utilisations max (null = illimité)
    quota_par_client INTEGER,                       -- par client (optionnel)
    actif BOOLEAN DEFAULT TRUE,
    priorite INTEGER DEFAULT 1000,                  -- priorité d'application
    commentaire TEXT,
    created_by UUID REFERENCES auth.users(id) DEFAULT auth.uid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. CONTRAINTES ET INDEXES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_promos_dates ON promotions(date_debut, date_fin) WHERE actif = TRUE;
CREATE INDEX IF NOT EXISTS idx_promos_client ON promotions(client_id) WHERE actif = TRUE;
CREATE INDEX IF NOT EXISTS idx_promos_produit ON promotions(produit_id) WHERE actif = TRUE;
CREATE INDEX IF NOT EXISTS idx_promos_canal ON promotions(canal_vente) WHERE actif = TRUE;
CREATE INDEX IF NOT EXISTS idx_promos_priorite ON promotions(priorite) WHERE actif = TRUE;

-- ============================================
-- 3. HISTORIQUE PROMOTIONS
-- ============================================

CREATE TABLE IF NOT EXISTS promotions_historique (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL,
    code_promo TEXT,
    nom TEXT,
    description TEXT,
    client_id UUID,
    canal_vente TEXT,
    produit_id UUID,
    type_promotion TEXT,
    valeur DECIMAL(10,2),
    quantite_min INTEGER,
    quantite_max INTEGER,
    montant_min DECIMAL(10,2),
    montant_max DECIMAL(10,2),
    date_debut DATE,
    date_fin DATE,
    quota_activations INTEGER,
    quota_par_client INTEGER,
    actif BOOLEAN,
    priorite INTEGER,
    commentaire TEXT,
    modif_type TEXT NOT NULL CHECK (modif_type IN ('creation', 'modification', 'desactivation', 'suppression')),
    modif_par UUID,
    modif_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_promos_hist_promo_id ON promotions_historique(promotion_id);

-- ============================================
-- 4. TABLE USAGE PROMOTIONS (log qui utilise quoi)
-- ============================================

CREATE TABLE IF NOT EXISTS promotions_usages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    promotion_id UUID NOT NULL REFERENCES promotions(id) ON DELETE CASCADE,
    client_id UUID REFERENCES partenaires(id) ON DELETE CASCADE,
    commande_id UUID REFERENCES commandes_client(id) ON DELETE CASCADE,
    usage_date TIMESTAMPTZ DEFAULT NOW(),
    montant_remise DECIMAL(10,2),
    created_by UUID REFERENCES auth.users(id) DEFAULT auth.uid()
);

CREATE INDEX IF NOT EXISTS idx_promos_usages_promo ON promotions_usages(promotion_id);
CREATE INDEX IF NOT EXISTS idx_promos_usages_client ON promotions_usages(client_id);

-- ============================================
-- 5. TRIGGERS
-- ============================================

CREATE TRIGGER trg_promotions_updated_at
BEFORE UPDATE ON promotions
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Historique automatique (insert, update, delete)
CREATE OR REPLACE FUNCTION trigger_promotions_history()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO promotions_historique (
            promotion_id, code_promo, nom, description, client_id, canal_vente, produit_id,
            type_promotion, valeur, quantite_min, quantite_max, montant_min, montant_max,
            date_debut, date_fin, quota_activations, quota_par_client, actif, priorite, commentaire,
            modif_type, modif_par
        ) VALUES (
            NEW.id, NEW.code_promo, NEW.nom, NEW.description, NEW.client_id, NEW.canal_vente, NEW.produit_id,
            NEW.type_promotion, NEW.valeur, NEW.quantite_min, NEW.quantite_max, NEW.montant_min, NEW.montant_max,
            NEW.date_debut, NEW.date_fin, NEW.quota_activations, NEW.quota_par_client, NEW.actif, NEW.priorite, NEW.commentaire,
            'creation', NEW.created_by
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO promotions_historique (
            promotion_id, code_promo, nom, description, client_id, canal_vente, produit_id,
            type_promotion, valeur, quantite_min, quantite_max, montant_min, montant_max,
            date_debut, date_fin, quota_activations, quota_par_client, actif, priorite, commentaire,
            modif_type, modif_par
        ) VALUES (
            NEW.id, NEW.code_promo, NEW.nom, NEW.description, NEW.client_id, NEW.canal_vente, NEW.produit_id,
            NEW.type_promotion, NEW.valeur, NEW.quantite_min, NEW.quantite_max, NEW.montant_min, NEW.montant_max,
            NEW.date_debut, NEW.date_fin, NEW.quota_activations, NEW.quota_par_client, NEW.actif, NEW.priorite, NEW.commentaire,
            'modification', auth.uid()
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO promotions_historique (
            promotion_id, code_promo, nom, description, client_id, canal_vente, produit_id,
            type_promotion, valeur, quantite_min, quantite_max, montant_min, montant_max,
            date_debut, date_fin, quota_activations, quota_par_client, actif, priorite, commentaire,
            modif_type, modif_par
        ) VALUES (
            OLD.id, OLD.code_promo, OLD.nom, OLD.description, OLD.client_id, OLD.canal_vente, OLD.produit_id,
            OLD.type_promotion, OLD.valeur, OLD.quantite_min, OLD.quantite_max, OLD.montant_min, OLD.montant_max,
            OLD.date_debut, OLD.date_fin, OLD.quota_activations, OLD.quota_par_client, OLD.actif, OLD.priorite, OLD.commentaire,
            'suppression', auth.uid()
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_promotions_history ON promotions;

CREATE TRIGGER trg_promotions_history
AFTER INSERT OR UPDATE OR DELETE
ON promotions
FOR EACH ROW
EXECUTE FUNCTION trigger_promotions_history();

-- ============================================
-- 6. RLS (Row Level Security)
-- ============================================

ALTER TABLE promotions ENABLE ROW LEVEL SECURITY;

-- Admin/Manager : accès total
CREATE POLICY "Admin manage promotions" ON promotions
FOR ALL USING (
    (auth.jwt() ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = auth.uid()
        AND ('admin' = ANY(tags) OR 'manager' = ANY(tags))
    )
);

-- Commercial : lecture seule
CREATE POLICY "Commercial read promotions" ON promotions
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM user_profiles
        WHERE id = auth.uid()
        AND ('commercial' = ANY(tags) OR 'manager' = ANY(tags))
    )
);

-- ============================================
-- 7. DOCUMENTATION
-- ============================================

COMMENT ON TABLE promotions IS
'Gestion complète des promotions par client, canal, produit, date, quantité, montant, quota, priorité.';

COMMENT ON COLUMN promotions.type_promotion IS
'remise_valeur = montant fixe, remise_pourcentage = %, offre_speciale = texte';

COMMENT ON TABLE promotions_historique IS
'Historique de toutes les modifications des promotions (audit complet)';

COMMENT ON TABLE promotions_usages IS
'Traçabilité de l’utilisation des promotions lors des commandes clients';

-- ============================================
-- 8. DONNÉES DE TEST (OPTIONNEL)
-- ============================================
/*
-- Promo générique -20% sur tout le site du 1er au 15 août
INSERT INTO promotions (nom, type_promotion, valeur, canal_vente, date_debut, date_fin)
VALUES ('SOLDES ETE -20%', 'remise_pourcentage', 20, 'site_web', '2025-08-01', '2025-08-15');

-- Promo client B2B : -10€ sur produit X par mail
INSERT INTO promotions (nom, type_promotion, valeur, canal_vente, produit_id, client_id, date_debut, date_fin)
VALUES ('OFFRE PRO MAIL', 'remise_valeur', 10, 'email', 'UUID-PRODUIT', 'UUID-CLIENT', '2025-07-01', '2025-07-31');
*/

-- ============================================
-- FIN DU FICHIER 14_promotions.sql
-- ============================================

