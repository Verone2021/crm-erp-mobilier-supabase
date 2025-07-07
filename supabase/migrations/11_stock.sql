/* 
=============================================================================
FICHIER : 11_stock.sql
OBJECTIF : Couche stock minimale pour tracer les mouvements et quantités
DÉPENDANCES : products (table existante)
ORDRE : Après 10_commandes_fournisseurs.sql
=============================================================================
*/

-- ============================================
-- 1. TABLE SUPPORT : warehouses (préparation multi-sites)
-- ============================================

CREATE TABLE IF NOT EXISTS warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nom TEXT NOT NULL UNIQUE,
    code TEXT NOT NULL UNIQUE, -- ex: 'MAIN', 'DEPOT2'
    adresse TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insérer l'entrepôt principal par défaut
INSERT INTO warehouses (nom, code) 
VALUES ('Entrepôt Principal', 'MAIN')
ON CONFLICT (nom) DO NOTHING;

-- ============================================
-- 2. TABLE PRINCIPALE : mouvements_stock
-- ============================================

CREATE TABLE IF NOT EXISTS mouvements_stock (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    warehouse_id UUID REFERENCES warehouses(id) ON DELETE RESTRICT,
    mouvement_type TEXT NOT NULL CHECK (
        mouvement_type IN ('IN', 'OUT', 'ADJUST', 'TRANSFER')
    ),
    quantite INTEGER NOT NULL CHECK (quantite > 0),
    quantite_effective INTEGER NOT NULL DEFAULT 0 CHECK (quantite_effective <> 0),
    source_table TEXT,
    ref_source_id UUID,
    cout_unitaire_ht DECIMAL(10,2),
    commentaire TEXT,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- 3. INDEX POUR PERFORMANCES
-- ============================================

CREATE INDEX IF NOT EXISTS idx_mouvements_product ON mouvements_stock(product_id);
CREATE INDEX IF NOT EXISTS idx_mouvements_date ON mouvements_stock(created_at);
CREATE INDEX IF NOT EXISTS idx_mouvements_type ON mouvements_stock(mouvement_type);
CREATE INDEX IF NOT EXISTS idx_mouvements_warehouse ON mouvements_stock(warehouse_id);
CREATE INDEX IF NOT EXISTS idx_mouvements_product_warehouse ON mouvements_stock(product_id, warehouse_id);

-- ============================================
-- 4. VUE : stock_courant (QOH = Quantity On Hand)
-- ============================================

CREATE OR REPLACE VIEW stock_courant AS
SELECT 
    p.id AS product_id,
    p.nom_complet AS produit_nom,
    p.ref_interne AS produit_ref,
    ms.warehouse_id,
    COALESCE(SUM(ms.quantite_effective), 0) AS qoh,
    p.seuil_alerte,
    CASE 
        WHEN p.seuil_alerte IS NULL THEN 'non_defini'
        WHEN COALESCE(SUM(ms.quantite_effective), 0) <= 0 THEN 'rupture'
        WHEN COALESCE(SUM(ms.quantite_effective), 0) <= p.seuil_alerte THEN 'alerte'
        ELSE 'ok'
    END AS status_stock,
    CASE 
        WHEN SUM(ms.quantite_effective) > 0 AND SUM(CASE WHEN ms.cout_unitaire_ht > 0 THEN ms.quantite_effective * ms.cout_unitaire_ht ELSE 0 END) > 0
        THEN ROUND(SUM(CASE WHEN ms.cout_unitaire_ht > 0 THEN ms.quantite_effective * ms.cout_unitaire_ht ELSE 0 END) / SUM(ms.quantite_effective), 2)
        ELSE NULL
    END AS cout_moyen_unitaire,
    MAX(ms.created_at) AS derniere_maj
FROM products p
LEFT JOIN mouvements_stock ms ON ms.product_id = p.id
WHERE p.is_active = TRUE
GROUP BY p.id, p.nom_complet, p.ref_interne, p.seuil_alerte, ms.warehouse_id;

-- ============================================
-- 5. VUE : stock_alertes (produits en situation critique)
-- ============================================

CREATE OR REPLACE VIEW stock_alertes AS
SELECT 
    product_id,
    produit_nom,
    produit_ref,
    warehouse_id,
    qoh,
    seuil_alerte,
    status_stock,
    cout_moyen_unitaire,
    CASE status_stock
        WHEN 'rupture' THEN 1
        WHEN 'alerte' THEN 2
        ELSE 3
    END AS priorite,
    derniere_maj
FROM stock_courant
WHERE status_stock IN ('rupture', 'alerte')
ORDER BY priorite, qoh ASC;

-- ============================================
-- 6. FONCTION UTILITAIRE : ajouter_mouvement_stock
-- ============================================

CREATE OR REPLACE FUNCTION ajouter_mouvement_stock(
    p_product_id UUID,
    p_type TEXT,
    p_quantite INTEGER,
    p_warehouse_id UUID DEFAULT NULL,
    p_source_table TEXT DEFAULT NULL,
    p_ref_source_id UUID DEFAULT NULL,
    p_commentaire TEXT DEFAULT NULL,
    p_cout_unitaire_ht DECIMAL DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mouvement_id UUID;
    v_quantite_effective INTEGER;
    v_qoh_actuel INTEGER;
BEGIN
    IF p_quantite <= 0 THEN
        RAISE EXCEPTION 'La quantité doit être positive (saisie : %)', p_quantite;
    END IF;

    IF p_type NOT IN ('IN', 'OUT', 'ADJUST', 'TRANSFER') THEN
        RAISE EXCEPTION 'Type de mouvement invalide: %', p_type;
    END IF;

    CASE p_type
        WHEN 'IN' THEN 
            v_quantite_effective := ABS(p_quantite);
        WHEN 'OUT' THEN 
            v_quantite_effective := -ABS(p_quantite);
        WHEN 'ADJUST' THEN
            v_quantite_effective := p_quantite;
        WHEN 'TRANSFER' THEN
            v_quantite_effective := -ABS(p_quantite);
        ELSE
            RAISE EXCEPTION 'Type non géré: %', p_type;
    END CASE;

    IF p_type IN ('OUT', 'TRANSFER') THEN
        SELECT COALESCE(SUM(quantite_effective), 0) 
        INTO v_qoh_actuel
        FROM mouvements_stock 
        WHERE product_id = p_product_id 
        AND (p_warehouse_id IS NULL OR warehouse_id = p_warehouse_id OR warehouse_id IS NULL);
        IF (v_qoh_actuel + v_quantite_effective) < 0 AND 
           NOT EXISTS (
               SELECT 1 FROM user_profiles 
               WHERE id = auth.uid() 
               AND 'admin' = ANY(tags)
           ) THEN
            RAISE EXCEPTION 'Stock insuffisant. Stock actuel: %, demandé: %', 
                v_qoh_actuel, ABS(v_quantite_effective);
        END IF;
    END IF;

    INSERT INTO mouvements_stock (
        product_id,
        warehouse_id,
        mouvement_type,
        quantite,
        quantite_effective,
        source_table,
        ref_source_id,
        commentaire,
        cout_unitaire_ht,
        created_by
    ) VALUES (
        p_product_id,
        p_warehouse_id,
        p_type,
        ABS(p_quantite),
        v_quantite_effective,
        p_source_table,
        p_ref_source_id,
        p_commentaire,
        p_cout_unitaire_ht,
        auth.uid()
    )
    RETURNING id INTO v_mouvement_id;

    RETURN v_mouvement_id;
END;
$$;

-- ============================================
-- 7. FONCTION BONUS : transferer_stock
-- ============================================

CREATE OR REPLACE FUNCTION transferer_stock(
    p_product_id UUID,
    p_quantite INTEGER,
    p_warehouse_source_id UUID,
    p_warehouse_dest_id UUID,
    p_commentaire TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mouvement_out_id UUID;
    v_mouvement_in_id UUID;
BEGIN
    IF p_quantite <= 0 THEN
        RAISE EXCEPTION 'La quantité de transfert doit être positive';
    END IF;

    IF p_warehouse_source_id = p_warehouse_dest_id THEN
        RAISE EXCEPTION 'Les entrepôts source et destination doivent être différents';
    END IF;

    SELECT ajouter_mouvement_stock(
        p_product_id,
        'TRANSFER',
        p_quantite,
        p_warehouse_source_id,
        'transfer',
        NULL,
        COALESCE(p_commentaire, 'Transfert inter-entrepôts')
    ) INTO v_mouvement_out_id;

    SELECT ajouter_mouvement_stock(
        p_product_id,
        'IN',
        p_quantite,
        p_warehouse_dest_id,
        'transfer',
        v_mouvement_out_id,
        COALESCE(p_commentaire, 'Transfert inter-entrepôts')
    ) INTO v_mouvement_in_id;

    RETURN jsonb_build_object(
        'success', true,
        'mouvement_sortie_id', v_mouvement_out_id,
        'mouvement_entree_id', v_mouvement_in_id,
        'quantite_transferee', p_quantite
    );
END;
$$;

-- ============================================
-- 8. RLS (Row Level Security)
-- ============================================

ALTER TABLE mouvements_stock ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Lecture mouvements stock" 
ON mouvements_stock FOR SELECT
USING (
    (auth.jwt() ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND ('admin' = ANY(tags) OR 'manager' = ANY(tags) OR 'stock' = ANY(tags))
    )
);

CREATE POLICY "Ecriture mouvements stock via fonctions" 
ON mouvements_stock FOR INSERT
WITH CHECK (
    (auth.jwt() ->> 'role') = 'admin'
    OR EXISTS (
        SELECT 1 FROM user_profiles 
        WHERE id = auth.uid() 
        AND ('admin' = ANY(tags) OR 'manager' = ANY(tags) OR 'stock' = ANY(tags))
    )
);

-- ============================================
-- 9. COMMENTAIRES ET DOCUMENTATION
-- ============================================

COMMENT ON TABLE warehouses IS 
'Entrepôts/sites de stockage. Prêt pour multi-sites futurs';

COMMENT ON TABLE mouvements_stock IS 
'Trace tous les mouvements de stock : entrées (IN), sorties (OUT), ajustements (ADJUST), transferts (TRANSFER)';

COMMENT ON COLUMN mouvements_stock.mouvement_type IS 
'IN=Entrée stock, OUT=Sortie stock, ADJUST=Ajustement inventaire, TRANSFER=Transfert entre entrepôts';

COMMENT ON COLUMN mouvements_stock.quantite IS 
'Quantité saisie (toujours positive sauf ADJUST). Le signe est calculé automatiquement dans quantite_effective';

COMMENT ON COLUMN mouvements_stock.quantite_effective IS 
'Quantité avec signe correct : IN=+, OUT=-, calculée par la fonction';

COMMENT ON COLUMN mouvements_stock.cout_unitaire_ht IS 
'Coût unitaire HT au moment du mouvement (pour valorisation stock FIFO/PMP)';

COMMENT ON COLUMN mouvements_stock.warehouse_id IS 
'Référence entrepôt (résolu automatiquement vers MAIN si NULL)';

COMMENT ON FUNCTION transferer_stock IS 
'Fonction de transfert sécurisé entre entrepôts (sortie + entrée atomique)';

COMMENT ON VIEW stock_courant IS 
'Vue temps réel du stock disponible par produit et entrepôt avec status d''alerte';

COMMENT ON VIEW stock_alertes IS 
'Vue des produits en rupture ou sous le seuil d''alerte, triés par priorité';

COMMENT ON FUNCTION ajouter_mouvement_stock IS 
'Fonction sécurisée pour ajouter un mouvement de stock avec traçabilité et vérifications';

-- ============================================
-- 10. DONNÉES DE TEST (optionnel)
-- ============================================

/*
-- Exemple : ajouter du stock initial pour quelques produits
INSERT INTO mouvements_stock (product_id, mouvement_type, quantite, quantite_effective, commentaire)
SELECT 
    id,
    'IN',
    50,
    50,
    'Stock initial de test'
FROM products 
WHERE is_active = TRUE 
LIMIT 5;
*/

-- ============================================
-- FIN DU FICHIER 11_stock.sql
-- ============================================

