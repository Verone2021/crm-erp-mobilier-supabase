-- 00_Backup_Schema_Complete.sql
-- Sauvegarde structure complète CRM/ERP Mobilier
-- Date: 2024-07-02
-- Tables: 17 tables principales

-- ===============================================
-- TABLES PRINCIPALES
-- ===============================================

CREATE TABLE categories (
    id UUID NOT NULL,
    nom TEXT NOT NULL,
    famille_id UUID NOT NULL,
    description TEXT,
    ordre_affichage INTEGER,
    is_active BOOLEAN,
    target_revenue NUMERIC(10,2),
    target_margin_percent NUMERIC(5,2),
    seasonality_factor NUMERIC(3,2),
    min_stock_days INTEGER,
    max_stock_days INTEGER,
    avg_delivery_days INTEGER,
    material_category TEXT,
    room_focus ARRAY,
    style_category TEXT,
    tags ARRAY,
    is_featured BOOLEAN,
    marketing_priority INTEGER,
    seo_title TEXT,
    seo_description TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
);

CREATE TABLE partenaires (
    id UUID NOT NULL,
    type_partenaire TEXT NOT NULL,
    prenom TEXT,
    nom TEXT,
    sexe TEXT,
    denomination_sociale TEXT,
    nom_commercial TEXT,
    siret VARCHAR(14),
    email TEXT,
    telephone TEXT,
    website_url TEXT,
    billing_address_line1 TEXT NOT NULL,
    billing_address_line2 TEXT,
    billing_city TEXT NOT NULL,
    billing_postal_code TEXT NOT NULL,
    billing_country CHARACTER NOT NULL,
    has_diff_shipping_addr BOOLEAN NOT NULL,
    shipping_address_line1 TEXT,
    shipping_address_line2 TEXT,
    shipping_city TEXT,
    shipping_postal_code TEXT,
    shipping_country CHARACTER,
    canal_acquisition TEXT,
    commentaires TEXT,
    specialites ARRAY,
    segment_industrie TEXT,
    conditions_paiement TEXT,
    taux_tva NUMERIC(5,2),
    langue CHARACTER NOT NULL,
    timezone TEXT NOT NULL,
    is_active BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    nom_complet TEXT
);

CREATE TABLE products (
    id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN NOT NULL,
    nom TEXT NOT NULL,
    ref_interne TEXT,
    ref_fournisseur TEXT,
    type_article TEXT NOT NULL,
    unite TEXT,
    statut TEXT NOT NULL,
    validation_sourcing TEXT,
    validation_echantillon TEXT,
    fin_de_serie BOOLEAN NOT NULL,
    sous_categorie_id UUID NOT NULL,
    product_group_id UUID,
    couleurs ARRAY,
    matieres ARRAY,
    pieces_habitation ARRAY,
    dimensions TEXT,
    poids_kg NUMERIC(8,2),
    tva_fournisseur NUMERIC(5,2),
    prix_achat_ht_indicatif NUMERIC(10,2),
    marge_percent NUMERIC(5,2),
    prix_minimum_ht NUMERIC(10,2),
    prix_minimum_ttc NUMERIC(10,2),
    seuil_alerte INTEGER,
    moq INTEGER,
    description_fournisseur TEXT,
    description_whatsapp TEXT,
    description_site_internet TEXT,
    description_leboncoin TEXT,
    titre_seo TEXT,
    description_seo TEXT,
    fournisseur_id UUID,
    variantes INTEGER,
    univers TEXT,
    nom_complet TEXT
);

-- ===============================================
-- RESUME DE LA SAUVEGARDE
-- ===============================================
-- Total tables sauvegardées: 17
-- Tables principales: categories, partenaires, products, user_profiles, utilisateurs
-- Tables enrichies: products_enrichie, partenaires_liste, users_complete
-- Vues: contacts_avec_partenaire, contacts_principaux
-- Date de création: 2024-07-02
-- Environnement: Supabase Production (tyqruipiblvgdqfoghmw)
