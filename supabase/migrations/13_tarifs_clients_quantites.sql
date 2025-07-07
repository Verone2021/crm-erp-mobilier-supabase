/*
=============================================================================
FICHIER : 13_tarifs_clients_quantites.sql (VERSION OPTIMISÉE)
OBJECTIF : Grilles tarifaires personnalisées (par client, canal, produit, quantité)
DÉPENDANCES : products, partenaires
ORDRE : Après 12_commandes_clients.sql
=============================================================================
*/

-- ============================================
-- 1. TABLE PRINCIPALE : tarifs_clients_quantites
-- ============================================

CREATE TABLE IF NOT EXISTS tarifs_clients_quantites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id UUID REFERENCES partenaires(id) ON DELETE CASCADE, -- NULL = tarif générique
    produit_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    canal_vente TEXT DEFAULT NULL CHECK (
        canal_vente IS NULL OR 
        canal_vente IN ('etsy', 'faire', 'site_web', 'salon', 'showroom', 'email', 'telephone')
    ), -- NULL = tous canaux
    quantite_min INTEGER NOT NULL DEFAULT 1 CHECK (quantite_min > 0),
    quantite_max INTEGER DEFAULT NULL CHECK (quantite_max IS NULL OR quantite_max >= quantite_min),
    prix_ht DECIMAL(10,2) NOT NULL CHECK (prix_ht > 0),
    devise TEXT DEFAULT 'EUR' CHECK (devise IN ('EUR', 'USD', 'GBP')),
    type_tarif TEXT DEFAULT 'standard' CHECK (type_tarif IN ('standard', 'promotion', 'nego_client', 'volume')),
    actif BOOLEAN DEFAULT TRUE,
    priorite INTEGER DEFAULT 1000, -- Plus petit = priorité haute
    commentaire TEXT,
    date_debut DATE DEFAULT CURRENT_DATE,
    date_fin DATE CHECK (date_fin IS NULL OR date_fin >= date_debut),
    created_by UUID REFERENCES auth.users(id) DEFAULT auth.uid(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. CONTRAINTES MÉTIER IMPORTANTES
-- ============================================

-- Pas de doublon client/produit/canal/quantité_min
CREATE UNIQUE INDEX IF NOT EXISTS uq_tarifs_client_produit_canal_qte
ON tarifs_clients_quantites(
    COALESCE(client_id::text, 'NULL'), 
    produit_id, 
    COALESCE(canal_vente, 'ALL'), 
    quantite_min
) WHERE actif = TRUE;

-- ============================================
-- 3. INDEXES POUR PERFORMANCE
-- ============================================

CREATE INDEX IF NOT EXISTS idx_tarifs_client_produit
ON tarifs_clients_quantites(client_id, produit_id, canal_vente, quantite_min);

CREATE INDEX IF NOT EXISTS idx_tarifs_canaux
ON tarifs_clients_quantites(canal_vente) WHERE actif = TRUE;

CREATE INDEX IF NOT EXISTS idx_tarifs_produit_actif
ON tarifs_clients_quantites(produit_id) WHERE actif = TRUE;

CREATE INDEX IF NOT EXISTS idx_tarifs_dates_validite
ON tarifs_clients_quantites(date_debut, date_fin) WHERE actif = TRUE;

CREATE INDEX IF NOT EXISTS idx_tarifs_priorite
ON tarifs_clients_quantites(priorite, quantite_min) WHERE actif = TRUE;

-- ============================================
-- 4. TABLE D'HISTORIQUE
-- ============================================

CREATE TABLE IF NOT EXISTS tarifs_clients_quantites_historique (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tarif_id UUID NOT NULL, -- Pas de FK CASCADE pour garder historique
    client_id UUID,
    produit_id UUID,
    canal_vente TEXT,
    quantite_min INTEGER,
    quantite_max INTEGER,
    prix_ht DECIMAL(10,2),
    devise TEXT,
    type_tarif TEXT,
    actif BOOLEAN,
    priorite INTEGER,
    commentaire TEXT,
    date_debut DATE,
    date_fin DATE,
    modif_type TEXT NOT NULL CHECK (modif_type IN ('creation', 'modification', 'desactivation', 'suppression')),
    modif_par UUID, -- Pas de FK pour éviter cascade
    modif_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_tarifs_hist_tarif_id ON tarifs_clients_quantites_historique(tarif_id);
CREATE INDEX IF NOT EXISTS idx_tarifs_hist_date ON tarifs_clients_quantites_historique(modif_at);

-- ============================================
-- 5. TRIGGER UPDATED_AT (réutilise fonction existante)
-- ============================================

CREATE TRIGGER trg_tarifs_clients_quantites_updated_at
BEFORE UPDATE ON tarifs_clients_quantites
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 6. TRIGGER HISTORIQUE
-- ============================================

CREATE OR REPLACE FUNCTION trigger_tarifs_clients_quantites_history()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO tarifs_clients_quantites_historique (
            tarif_id, client_id, produit_id, canal_vente, quantite_min, quantite_max, 
            prix_ht, devise, type_tarif, actif, priorite, commentaire, 
            date_debut, date_fin, modif_type, modif_par
        ) VALUES (
            NEW.id, NEW.client_id, NEW.produit_id, NEW.canal_vente, NEW.quantite_min, NEW.quantite_max,
            NEW.prix_ht, NEW.devise, NEW.type_tarif, NEW.actif, NEW.priorite, NEW.commentaire,
            NEW.date_debut, NEW.date_fin, 'creation', NEW.created_by
        );
        RETURN NEW;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO tarifs_clients_quantites_historique (
            tarif_id, client_id, produit_id, canal_vente, quantite_min, quantite_max,
            prix_ht, devise, type_tarif, actif, priorite, commentaire,
            date_debut, date_fin, modif_type, modif_par
        ) VALUES (
            NEW.id, NEW.client_id, NEW.produit_id, NEW.canal_vente, NEW.quantite_min, NEW.quantite_max,
            NEW.prix_ht, NEW.devise, NEW.type_tarif, NEW.actif, NEW.priorite, NEW.commentaire,
            NEW.date_debut, NEW.date_fin, 'modification', auth.uid()
        );
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO tarifs_clients_quantites_historique (
            tarif_id, client_id, produit_id, canal_vente, quantite_min, quantite_max,
            prix_ht, devise, type_tarif, actif, priorite, commentaire,
            date_debut, date_fin, modif_type, modif_par
        ) VALUES (
            OLD.id, OLD.client_id, OLD.produit_id, OLD.canal_vente, OLD.quantite_min, OLD.quantite_max,
            OLD.prix_ht, OLD.devise, OLD.type_tarif, OLD.actif, OLD.priorite, OLD.commentaire,
            OLD.date_debut, OLD.date_fin, 'suppression', auth.uid()
        );
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Attacher le trigger
DROP TRIGGER IF EXISTS trg_tarifs_clients_quantites_history ON tarifs_clients_quantites;

CREATE TRIGGER trg_tarifs_clients_quantites_history
AFTER INSERT OR UPDATE OR DELETE
ON tarifs_clients_quantites
FOR EACH ROW
EXECUTE FUNCTION trigger_tarifs_clients_quantites_history();

-- ============================================
-- 7. FONCTION UTILITAIRE : Recherche du meilleur prix
-- ============================================

CREATE OR REPLACE FUNCTION obtenir_meilleur_prix(
    p_client_id UUID,
    p_produit_id UUID,
    p_canal_vente TEXT DEFAULT NULL,
    p_quantite INTEGER DEFAULT 1
) RETURNS DECIMAL(10,2)
LANGUAGE plpgsql
AS $$
DECLARE
    v_prix DECIMAL(10,2);
BEGIN
    -- Recherche par ordre de priorité :
    -- 1. Tarif spécifique client + canal + quantité
    -- 2. Tarif générique canal + quantité
    -- 3. Tarif par défaut produit
    
    SELECT prix_ht INTO v_prix
    FROM tarifs_clients_quantites
    WHERE produit_id = p_produit_id
      AND actif = TRUE
      AND (date_debut IS NULL OR date_debut <= CURRENT_DATE)
      AND (date_fin IS NULL OR date_fin >= CURRENT_DATE)
      AND quantite_min <= p_quantite
      AND (quantite_max IS NULL OR quantite_max >= p_quantite)
      AND (
          -- Priorité 1: Client spécifique + canal spécifique
          (client_id = p_client_id AND canal_vente = p_canal_vente) OR
          -- Priorité 2: Client spécifique + tous canaux
          (client_id = p_client_id AND canal_vente IS NULL) OR
          -- Priorité 3: Tous clients + canal spécifique
          (client_id IS NULL AND canal_vente = p_canal_vente) OR
          -- Priorité 4: Tarif générique
          (client_id IS NULL AND canal_vente IS NULL)
      )
    ORDER BY 
        CASE 
            WHEN client_id = p_client_id AND canal_vente = p_canal_vente THEN 1
            WHEN client_id = p_client_id AND canal_vente IS NULL THEN 2
            WHEN client_id IS NULL AND canal_vente = p_canal_vente THEN 3
            WHEN client_id IS NULL AND canal_vente IS NULL THEN 4
        END,
        priorite ASC,
        quantite_min DESC
    LIMIT 1;
    
    -- Si aucun tarif trouvé, utiliser le prix du produit
    IF v_prix IS NULL THEN
        SELECT prix_minimum_ht INTO v_prix
        FROM products
        WHERE id = p_produit_id;
    END IF;
    
    RETURN COALESCE(v_prix, 0);
END;
$$;

-- ============================================
-- 8. VUE UTILITAIRE : Tarifs actifs enrichis
-- ============================================

CREATE OR REPLACE VIEW tarifs_actifs_enrichis AS
SELECT 
    t.id,
    t.client_id,
    COALESCE(p.nom_complet, 'Tarif générique') AS client_nom,
    t.produit_id,
    pr.nom_complet AS produit_nom,
    pr.ref_interne AS produit_ref,
    t.canal_vente,
    t.quantite_min,
    t.quantite_max,
    t.prix_ht,
    t.devise,
    t.type_tarif,
    t.priorite,
    t.date_debut,
    t.date_fin,
    CASE 
        WHEN t.date_fin IS NOT NULL AND t.date_fin < CURRENT_DATE THEN 'Expiré'
        WHEN t.date_debut > CURRENT_DATE THEN 'À venir'
        ELSE 'Actif'
    END AS statut_validite,
    t.commentaire,
    t.created_at,
    t.updated_at
FROM tarifs_clients_quantites t
LEFT JOIN partenaires p ON p.id = t.client_id
JOIN products pr ON pr.id = t.produit_id
WHERE t.actif = TRUE
ORDER BY t.priorite, t.quantite_min;

-- ============================================
-- 9. RLS (Row Level Security)
-- ============================================

ALTER TABLE tarifs_clients_quantites ENABLE ROW LEVEL SECURITY;

-- Admin/Manager : accès total
CREATE POLICY "Admin manage tarifs" ON tarifs_clients_quantites
FOR ALL USING (
    (auth.jwt() ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND ('admin' = ANY(tags) OR 'manager' = ANY(tags))
    )
);

-- Commercial : lecture + création
CREATE POLICY "Commercial read tarifs" ON tarifs_clients_quantites
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND ('commercial' = ANY(tags) OR 'manager' = ANY(tags))
    )
);

-- ============================================
-- 10. COMMENTAIRES ET DOCUMENTATION
-- ============================================

COMMENT ON TABLE tarifs_clients_quantites IS
'Grille tarifaire personnalisée par client, produit, canal de vente et quantité (tarifs dégressifs)';

COMMENT ON COLUMN tarifs_clients_quantites.client_id IS
'NULL = tarif générique pour tous les clients';

COMMENT ON COLUMN tarifs_clients_quantites.canal_vente IS
'NULL = tous canaux, sinon canal spécifique (etsy, faire, site_web, etc.)';

COMMENT ON COLUMN tarifs_clients_quantites.priorite IS
'Plus petit = priorité haute pour résolution conflits';

COMMENT ON COLUMN tarifs_clients_quantites.type_tarif IS
'Type de tarif : standard, promotion, nego_client, volume';

COMMENT ON TABLE tarifs_clients_quantites_historique IS
'Historique complet des modifications de tarifs (audit trail)';

COMMENT ON FUNCTION obtenir_meilleur_prix IS
'Fonction pour trouver le meilleur prix selon client, produit, canal et quantité';

COMMENT ON VIEW tarifs_actifs_enrichis IS
'Vue enrichie des tarifs actifs avec noms clients/produits et statut validité';

-- ============================================
-- 11. DONNÉES DE TEST (OPTIONNEL)
-- ============================================

/*
-- Exemple : tarifs génériques pour quelques produits
INSERT INTO tarifs_clients_quantites (produit_id, quantite_min, prix_ht, type_tarif, commentaire)
SELECT 
    id,
    1,
    prix_minimum_ht,
    'standard',
    'Tarif de base générique'
FROM products 
WHERE is_active = TRUE 
LIMIT 3;

-- Exemple : tarif client spécifique avec dégressif
INSERT INTO tarifs_clients_quantites (client_id, produit_id, quantite_min, quantite_max, prix_ht, type_tarif, commentaire)
VALUES 
    ((SELECT id FROM partenaires WHERE type_partenaire='client_pro' LIMIT 1), 
     (SELECT id FROM products LIMIT 1), 
     10, 49, 85.00, 'volume', 'Tarif dégressif 10-49 unités'),
    ((SELECT id FROM partenaires WHERE type_partenaire='client_pro' LIMIT 1), 
     (SELECT id FROM products LIMIT 1), 
     50, NULL, 75.00, 'volume', 'Tarif dégressif 50+ unités');
*/

-- ============================================
-- FIN DU FICHIER 13_tarifs_clients_quantites.sql
-- ============================================
