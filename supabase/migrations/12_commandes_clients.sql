/* 
=============================================================================
FICHIER : 12_commandes_clients.sql
OBJECTIF : Gestion complète des commandes clients (B2B + B2C)
DÉPENDANCES : products, partenaires, mouvements_stock (11_stock.sql)
ORDRE : Après 11_stock.sql
=============================================================================
*/

-- ============================================
-- 1. TABLE PRINCIPALE : commandes_client
-- ============================================

CREATE TABLE IF NOT EXISTS commandes_client (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    numero_commande TEXT UNIQUE NOT NULL,
    client_id UUID NOT NULL REFERENCES partenaires(id) ON DELETE RESTRICT,
    validateur_id UUID REFERENCES auth.users(id),
    statut TEXT NOT NULL DEFAULT 'brouillon' CHECK (
        statut IN ('brouillon', 'validee', 'en_attente_paiement', 'payee', 'preparee', 'expediee', 'livree', 'annulee')
    ),
    canal_commande TEXT NOT NULL DEFAULT 'site_web' CHECK (
        canal_commande IN ('site_web', 'email', 'telephone', 'autre')
    ),
    date_commande TIMESTAMPTZ DEFAULT NOW(),
    date_validation TIMESTAMPTZ,
    date_livraison_souhaitee DATE,
    date_livraison_prevue DATE,
    date_expedition TIMESTAMPTZ,
    date_livraison_reelle TIMESTAMPTZ,
    nb_lignes INTEGER DEFAULT 0,
    quantite_totale INTEGER DEFAULT 0,
    total_ht DECIMAL(12,2) DEFAULT 0,
    total_tva DECIMAL(12,2) DEFAULT 0,
    total_eco_participation DECIMAL(12,2) DEFAULT 0,
    frais_livraison DECIMAL(10,2) DEFAULT 0,
    total_ttc DECIMAL(12,2) DEFAULT 0,
    adresse_facturation JSONB NOT NULL,
    adresse_livraison JSONB,
    commentaire_client TEXT,
    notes_internes TEXT,
    transporteur TEXT,
    numero_suivi TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 2. TABLE LIGNES : commande_client_lignes
-- ============================================

CREATE TABLE IF NOT EXISTS commande_client_lignes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    commande_id UUID NOT NULL REFERENCES commandes_client(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    quantite INTEGER NOT NULL CHECK (quantite > 0),
    quantite_preparee INTEGER DEFAULT 0 CHECK (quantite_preparee >= 0),
    quantite_expediee INTEGER DEFAULT 0 CHECK (quantite_expediee >= 0),
    prix_unitaire_ht DECIMAL(10,2) NOT NULL,
    taux_tva DECIMAL(5,2) DEFAULT 20.0,
    eco_participation_unitaire DECIMAL(8,2) DEFAULT 0,
    montant_ht DECIMAL(10,2) GENERATED ALWAYS AS (quantite * prix_unitaire_ht) STORED,
    montant_tva DECIMAL(10,2) GENERATED ALWAYS AS (quantite * prix_unitaire_ht * taux_tva / 100) STORED,
    montant_eco DECIMAL(10,2) GENERATED ALWAYS AS (quantite * eco_participation_unitaire) STORED,
    montant_ttc DECIMAL(10,2) GENERATED ALWAYS AS (
        quantite * prix_unitaire_ht * (1 + taux_tva / 100) + quantite * eco_participation_unitaire
    ) STORED,
    statut_ligne TEXT DEFAULT 'en_attente' CHECK (
        statut_ligne IN ('en_attente', 'preparee', 'partiellement_expediee', 'expediee')
    ),
    UNIQUE(commande_id, product_id),
    CHECK (quantite_preparee <= quantite),
    CHECK (quantite_expediee <= quantite_preparee),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. INDEX POUR PERFORMANCES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_commandes_client_statut ON commandes_client(statut);
CREATE INDEX IF NOT EXISTS idx_commandes_client_date ON commandes_client(date_commande);
CREATE INDEX IF NOT EXISTS idx_commandes_client_client ON commandes_client(client_id);
CREATE INDEX IF NOT EXISTS idx_commandes_client_numero ON commandes_client(numero_commande);
CREATE INDEX IF NOT EXISTS idx_commandes_client_livraison ON commandes_client(date_livraison_souhaitee);

CREATE INDEX IF NOT EXISTS idx_lignes_client_commande ON commande_client_lignes(commande_id);
CREATE INDEX IF NOT EXISTS idx_lignes_client_product ON commande_client_lignes(product_id);
CREATE INDEX IF NOT EXISTS idx_lignes_client_statut ON commande_client_lignes(statut_ligne);

-- ============================================
-- 4. FONCTION : Génération numéro commande
-- ============================================

CREATE OR REPLACE FUNCTION generer_numero_commande_client()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    v_annee TEXT;
    v_numero INTEGER;
    v_numero_formate TEXT;
BEGIN
    v_annee := EXTRACT(YEAR FROM NOW())::TEXT;
    SELECT COALESCE(
        MAX(
            CAST(
                SPLIT_PART(
                    REPLACE(numero_commande, 'CMD-CLI-' || v_annee || '-', ''), 
                    '-', 1
                ) AS INTEGER
            )
        ), 0
    ) + 1
    INTO v_numero
    FROM commandes_client 
    WHERE numero_commande LIKE 'CMD-CLI-' || v_annee || '-%';
    v_numero_formate := 'CMD-CLI-' || v_annee || '-' || LPAD(v_numero::TEXT, 3, '0');
    RETURN v_numero_formate;
END;
$$;

-- ============================================
-- 5. FONCTION : Créer commande client
-- ============================================

CREATE OR REPLACE FUNCTION creer_commande_client(
    p_client_id UUID,
    p_canal TEXT DEFAULT 'site_web',
    p_date_livraison_souhaitee DATE DEFAULT NULL,
    p_adresse_facturation JSONB DEFAULT NULL,
    p_adresse_livraison JSONB DEFAULT NULL,
    p_commentaire_client TEXT DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_commande_id UUID;
    v_numero_commande TEXT;
    v_adresse_facturation JSONB;
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM partenaires 
        WHERE id = p_client_id 
        AND type_partenaire IN ('client_particulier', 'client_pro')
        AND is_active = TRUE
    ) THEN
        RAISE EXCEPTION 'Client invalide ou inactif: %', p_client_id;
    END IF;
    v_numero_commande := generer_numero_commande_client();
    IF p_adresse_facturation IS NULL THEN
        SELECT jsonb_build_object(
            'nom_complet', nom_complet,
            'adresse1', billing_address_line1,
            'adresse2', billing_address_line2,
            'code_postal', billing_postal_code,
            'ville', billing_city,
            'pays', billing_country
        ) INTO v_adresse_facturation
        FROM partenaires 
        WHERE id = p_client_id;
    ELSE
        v_adresse_facturation := p_adresse_facturation;
    END IF;
    INSERT INTO commandes_client (
        numero_commande,
        client_id,
        canal_commande,
        date_livraison_souhaitee,
        adresse_facturation,
        adresse_livraison,
        commentaire_client
    ) VALUES (
        v_numero_commande,
        p_client_id,
        p_canal,
        p_date_livraison_souhaitee,
        v_adresse_facturation,
        p_adresse_livraison,
        p_commentaire_client
    )
    RETURNING id INTO v_commande_id;
    RETURN v_commande_id;
END;
$$;

-- ============================================
-- 6. FONCTION : Ajouter ligne commande
-- ============================================

CREATE OR REPLACE FUNCTION ajouter_ligne_commande_client(
    p_commande_id UUID,
    p_product_id UUID,
    p_quantite INTEGER,
    p_prix_unitaire_ht DECIMAL DEFAULT NULL,
    p_taux_tva DECIMAL DEFAULT NULL,
    p_eco_participation DECIMAL DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_ligne_id UUID;
    v_prix_ht DECIMAL(10,2);
    v_tva DECIMAL(5,2);
    v_eco DECIMAL(8,2);
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM commandes_client 
        WHERE id = p_commande_id 
        AND statut IN ('brouillon', 'validee')
    ) THEN
        RAISE EXCEPTION 'Commande non modifiable (statut avancé)';
    END IF;
    SELECT 
        COALESCE(p_prix_unitaire_ht, prix_minimum_ht, 0),
        COALESCE(p_taux_tva, tva_fournisseur, 20.0),
        COALESCE(p_eco_participation, 0)
    INTO v_prix_ht, v_tva, v_eco
    FROM products 
    WHERE id = p_product_id;
    IF v_prix_ht IS NULL THEN
        RAISE EXCEPTION 'Produit introuvable: %', p_product_id;
    END IF;
    INSERT INTO commande_client_lignes (
        commande_id,
        product_id,
        quantite,
        prix_unitaire_ht,
        taux_tva,
        eco_participation_unitaire
    ) VALUES (
        p_commande_id,
        p_product_id,
        p_quantite,
        v_prix_ht,
        v_tva,
        v_eco
    )
    ON CONFLICT (commande_id, product_id) 
    DO UPDATE SET 
        quantite = commande_client_lignes.quantite + p_quantite,
        updated_at = NOW()
    RETURNING id INTO v_ligne_id;
    RETURN v_ligne_id;
END;
$$;

-- ============================================
-- 7. FONCTION : Recalculer totaux commande
-- ============================================

CREATE OR REPLACE FUNCTION recalculer_totaux_commande_client(p_commande_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_nb_lignes INTEGER;
    v_quantite_totale INTEGER;
    v_total_ht DECIMAL(12,2);
    v_total_tva DECIMAL(12,2);
    v_total_eco DECIMAL(12,2);
    v_total_ttc DECIMAL(12,2);
BEGIN
    SELECT 
        COUNT(*),
        COALESCE(SUM(quantite), 0),
        COALESCE(SUM(montant_ht), 0),
        COALESCE(SUM(montant_tva), 0),
        COALESCE(SUM(montant_eco), 0),
        COALESCE(SUM(montant_ttc), 0)
    INTO 
        v_nb_lignes,
        v_quantite_totale,
        v_total_ht,
        v_total_tva,
        v_total_eco,
        v_total_ttc
    FROM commande_client_lignes
    WHERE commande_id = p_commande_id;
    UPDATE commandes_client SET
        nb_lignes = v_nb_lignes,
        quantite_totale = v_quantite_totale,
        total_ht = v_total_ht,
        total_tva = v_total_tva,
        total_eco_participation = v_total_eco,
        total_ttc = v_total_ttc + frais_livraison,
        updated_at = NOW()
    WHERE id = p_commande_id;
END;
$$;

-- ============================================
-- 8. TRIGGERS : Recalcul automatique
-- ============================================

CREATE OR REPLACE FUNCTION trigger_recalc_commande_client()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM recalculer_totaux_commande_client(
        COALESCE(NEW.commande_id, OLD.commande_id)
    );
    RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER trg_recalc_commande_client_totaux
    AFTER INSERT OR UPDATE OR DELETE ON commande_client_lignes
    FOR EACH ROW
    EXECUTE FUNCTION trigger_recalc_commande_client();

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_commandes_client_updated_at
    BEFORE UPDATE ON commandes_client
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_lignes_client_updated_at
    BEFORE UPDATE ON commande_client_lignes
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- 9. VUES MÉTIER
-- ============================================

CREATE OR REPLACE VIEW commandes_client_en_cours AS
SELECT 
    cc.*,
    p.nom_complet AS client_nom,
    p.type_partenaire AS client_type,
    p.email AS client_email,
    CASE 
        WHEN cc.date_livraison_souhaitee < CURRENT_DATE THEN 'En retard'
        WHEN cc.date_livraison_souhaitee = CURRENT_DATE THEN 'Aujourd''hui'
        WHEN cc.date_livraison_souhaitee <= CURRENT_DATE + INTERVAL '7 days' THEN 'Cette semaine'
        ELSE 'Plus tard'
    END AS urgence_livraison,
    CASE cc.statut
        WHEN 'brouillon' THEN 10
        WHEN 'validee' THEN 20
        WHEN 'en_attente_paiement' THEN 30
        WHEN 'payee' THEN 50
        WHEN 'preparee' THEN 70
        WHEN 'expediee' THEN 90
        WHEN 'livree' THEN 100
        ELSE 0
    END AS progression_percent
FROM commandes_client cc
JOIN partenaires p ON p.id = cc.client_id
WHERE cc.statut NOT IN ('livree', 'annulee')
ORDER BY cc.date_commande DESC;

CREATE OR REPLACE VIEW lignes_commande_detail AS
SELECT 
    ccl.*,
    cc.numero_commande,
    cc.statut AS commande_statut,
    p.nom_complet AS produit_nom,
    p.ref_interne AS produit_ref,
    ROUND(ccl.quantite_expediee * 100.0 / ccl.quantite, 1) AS progression_expedition
FROM commande_client_lignes ccl
JOIN commandes_client cc ON cc.id = ccl.commande_id
JOIN products p ON p.id = ccl.product_id
ORDER BY cc.date_commande DESC, ccl.created_at;

-- ============================================
-- 10. RLS (Row Level Security)
-- ============================================

ALTER TABLE commandes_client ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lecture commandes client" 
ON commandes_client FOR SELECT
USING (
    (auth.jwt() ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND ('admin' = ANY(tags) OR 'manager' = ANY(tags) OR 'commercial' = ANY(tags))
    )
);

CREATE POLICY "Gestion commandes client" 
ON commandes_client FOR ALL
USING (
    (auth.jwt() ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND ('admin' = ANY(tags) OR 'manager' = ANY(tags))
    )
);

ALTER TABLE commande_client_lignes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Accès lignes commande client" 
ON commande_client_lignes FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM commandes_client cc
        WHERE cc.id = commande_id
    )
);

-- ============================================
-- 11. COMMENTAIRES ET DOCUMENTATION
-- ============================================

COMMENT ON TABLE commandes_client IS 
'Commandes clients B2B et B2C avec workflow validation manuelle';
COMMENT ON COLUMN commandes_client.statut IS 
'brouillon → validee → en_attente_paiement → payee → preparee → expediee → livree';
COMMENT ON COLUMN commandes_client.canal_commande IS 
'Canal de réception : site_web, email, telephone, autre';
COMMENT ON COLUMN commandes_client.adresse_facturation IS 
'Snapshot JSONB de l''adresse de facturation au moment de la commande';
COMMENT ON TABLE commande_client_lignes IS 
'Détail des lignes de commande avec prix figés et quantités de suivi';
COMMENT ON VIEW commandes_client_en_cours IS 
'Vue métier des commandes non terminées avec indicateurs d''urgence';
COMMENT ON FUNCTION creer_commande_client IS 
'Création sécurisée d''une nouvelle commande avec numérotation automatique';
COMMENT ON FUNCTION ajouter_ligne_commande_client IS 
'Ajout de ligne avec récupération automatique des prix produit si non fournis';

-- ============================================
-- 12. AUTOMATISATION STOCK : Mouvement à l'expédition
-- ============================================

CREATE OR REPLACE FUNCTION gerer_mouvement_stock_expedition(p_commande_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r_ligne RECORD;
    v_warehouse_id UUID;
BEGIN
    SELECT id INTO v_warehouse_id 
    FROM warehouses 
    WHERE code = 'MAIN' AND is_active = TRUE
    LIMIT 1;
    IF v_warehouse_id IS NULL THEN
        RAISE EXCEPTION 'Entrepôt principal (MAIN) introuvable';
    END IF;
    FOR r_ligne IN 
        SELECT ccl.*, p.nom_complet as produit_nom
        FROM commande_client_lignes ccl
        JOIN products p ON p.id = ccl.product_id
        WHERE ccl.commande_id = p_commande_id
        AND ccl.quantite_expediee > 0
    LOOP
        PERFORM ajouter_mouvement_stock(
            r_ligne.product_id,
            'OUT',
            r_ligne.quantite_expediee,
            v_warehouse_id,
            'commande_client_lignes',
            r_ligne.id,
            'Expédition commande client - ' || r_ligne.produit_nom
        );
        INSERT INTO logs_stock (
            action, 
            details, 
            created_at
        ) VALUES (
            'EXPEDITION_CLIENT',
            jsonb_build_object(
                'commande_id', p_commande_id,
                'ligne_id', r_ligne.id,
                'product_id', r_ligne.product_id,
                'quantite', r_ligne.quantite_expediee
            ),
            NOW()
        ) ON CONFLICT DO NOTHING;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION trigger_expedition_commande_client()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.statut != 'expediee' AND NEW.statut = 'expediee' THEN
        PERFORM gerer_mouvement_stock_expedition(NEW.id);
        NEW.date_expedition = NOW();
    END IF;
    IF OLD.statut != 'livree' AND NEW.statut = 'livree' THEN
        NEW.date_livraison_reelle = NOW();
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_expedition_commande_client
    BEFORE UPDATE ON commandes_client
    FOR EACH ROW
    EXECUTE FUNCTION trigger_expedition_commande_client();

-- ============================================
-- 13. TABLE LOGS OPTIONNELLE (pour traçabilité)
-- ============================================

CREATE TABLE IF NOT EXISTS logs_stock (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    action TEXT NOT NULL,
    details JSONB,
    created_by UUID REFERENCES auth.users(id) DEFAULT auth.uid(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_logs_stock_action ON logs_stock(action);
CREATE INDEX IF NOT EXISTS idx_logs_stock_date ON logs_stock(created_at);

COMMENT ON TABLE logs_stock IS 
'Journal des actions importantes sur le stock (expéditions, réceptions, ajustements)';

-- ============================================
-- 14. FONCTION BONUS : Validation stock avant expédition
-- ============================================

CREATE OR REPLACE FUNCTION verifier_stock_avant_expedition(p_commande_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    r_ligne RECORD;
    v_stock_actuel INTEGER;
    v_problemes JSONB := '[]'::jsonb;
    v_warehouse_id UUID;
BEGIN
    SELECT id INTO v_warehouse_id 
    FROM warehouses 
    WHERE code = 'MAIN' AND is_active = TRUE
    LIMIT 1;
    FOR r_ligne IN 
        SELECT ccl.*, p.nom_complet as produit_nom, p.ref_interne
        FROM commande_client_lignes ccl
        JOIN products p ON p.id = ccl.product_id
        WHERE ccl.commande_id = p_commande_id
    LOOP
        SELECT COALESCE(SUM(quantite_effective), 0) 
        INTO v_stock_actuel
        FROM mouvements_stock 
        WHERE product_id = r_ligne.product_id 
        AND warehouse_id = v_warehouse_id;
        IF v_stock_actuel < r_ligne.quantite THEN
            v_problemes := v_problemes || jsonb_build_object(
                'product_id', r_ligne.product_id,
                'produit_nom', r_ligne.produit_nom,
                'ref_interne', r_ligne.ref_interne,
                'quantite_demandee', r_ligne.quantite,
                'stock_disponible', v_stock_actuel,
                'manque', r_ligne.quantite - v_stock_actuel
            );
        END IF;
    END LOOP;
    RETURN jsonb_build_object(
        'expedition_possible', jsonb_array_length(v_problemes) = 0,
        'problemes_stock', v_problemes,
        'nb_problemes', jsonb_array_length(v_problemes)
    );
END;
$$;

COMMENT ON FUNCTION verifier_stock_avant_expedition IS 
'Vérifie si le stock est suffisant avant de passer une commande en statut expédiée';
COMMENT ON FUNCTION gerer_mouvement_stock_expedition IS 
'Automatise la sortie de stock lors du passage en statut expédiée';

-- ============================================
-- FIN DU FICHIER 12_commandes_clients.sql
-- ============================================

