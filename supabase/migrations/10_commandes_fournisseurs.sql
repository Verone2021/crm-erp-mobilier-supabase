/* ================================================================
   10_commandes_fournisseurs.sql – PARTIE 1
   Tables : commandes_fournisseur • commande_fournisseur_lignes • commande_relances
   Version propre, compatible Supabase (aucun DO $$)
   ============================================================== */

/* ----------------------------------------------------------------
   1. TABLE PRINCIPALE : commandes_fournisseur
   ---------------------------------------------------------------- */
CREATE TABLE IF NOT EXISTS commandes_fournisseur (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero_commande          TEXT UNIQUE NOT NULL,

  -- Relations
  fournisseur_id           UUID REFERENCES partenaires(id) ON DELETE RESTRICT,
  commandeur_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  validateur_id            UUID REFERENCES auth.users(id),

  -- Statuts & workflow
  statut TEXT NOT NULL DEFAULT 'brouillon' CHECK (
    statut IN ('brouillon','validee','confirmee','expediee',
               'partiellement_recue','entierement_recue','terminee','annulee')
  ),

  -- Dates
  date_commande               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  date_validation             TIMESTAMPTZ,
  date_confirmation_fournisseur TIMESTAMPTZ,
  date_expedition_prevue      DATE,
  date_livraison_prevue       DATE,
  date_livraison_souhaitee    DATE,
  date_reception_complete     TIMESTAMPTZ,

  -- Conditions commerciales
  conditions_paiement         TEXT DEFAULT 'NET30',    -- NET30, NET15, IMMEDIAT
  mode_livraison              TEXT DEFAULT 'standard', -- standard, express, sur_rdv
  devise                      TEXT NOT NULL DEFAULT 'EUR',
  taux_change                 DECIMAL(10,6) DEFAULT 1.0,

  -- Livraison & transport
  adresse_livraison           JSONB,
  entrepot_destination        TEXT NOT NULL DEFAULT 'principal',
  transporteur_prefere        TEXT,
  instructions_livraison      TEXT,

  -- Frais globaux
  frais_livraison             DECIMAL(10,2) DEFAULT 0,
  methode_repartition_livraison TEXT DEFAULT 'unite'  CHECK (methode_repartition_livraison IN ('unite','poids','valeur')),
  taxes_globales              DECIMAL(10,2) DEFAULT 0,
  methode_repartition_taxes   TEXT DEFAULT 'valeur'   CHECK (methode_repartition_taxes    IN ('unite','poids','valeur')),

  -- Métriques & totaux (remplis par triggers)
  nb_lignes                   INTEGER DEFAULT 0,
  nb_references               INTEGER DEFAULT 0,
  quantite_totale_elements    INTEGER DEFAULT 0,
  densite_commande            DECIMAL(8,2),

  total_achat_ht              DECIMAL(12,2) DEFAULT 0,
  total_tva                   DECIMAL(12,2) DEFAULT 0,
  total_eco_participation     DECIMAL(12,2) DEFAULT 0,
  total_taxes_unitaires       DECIMAL(12,2) DEFAULT 0,
  total_achat_ttc             DECIMAL(12,2) DEFAULT 0,

  total_vente_theorique_ht    DECIMAL(12,2) DEFAULT 0,
  total_vente_theorique_ttc   DECIMAL(12,2) DEFAULT 0,

  progression_reception_percent  DECIMAL(5,2) DEFAULT 0,
  progression_references_percent DECIMAL(5,2) DEFAULT 0,

  -- Notes
  commentaires_internes       TEXT,
  commentaires_fournisseur    TEXT,

  -- Audit
  created_at                  TIMESTAMPTZ DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ DEFAULT NOW()
);

/* Index commandes_fournisseur */
CREATE INDEX IF NOT EXISTS idx_cmd_fournisseur_statut     ON commandes_fournisseur(statut);
CREATE INDEX IF NOT EXISTS idx_cmd_fournisseur_fourn      ON commandes_fournisseur(fournisseur_id);
CREATE INDEX IF NOT EXISTS idx_cmd_fournisseur_dates      ON commandes_fournisseur(date_commande, date_livraison_prevue);
CREATE INDEX IF NOT EXISTS idx_cmd_fournisseur_numero     ON commandes_fournisseur(numero_commande);

/* ----------------------------------------------------------------
   2. TABLE LIGNES : commande_fournisseur_lignes
   ---------------------------------------------------------------- */
CREATE TABLE IF NOT EXISTS commande_fournisseur_lignes (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commande_id          UUID NOT NULL REFERENCES commandes_fournisseur(id) ON DELETE CASCADE,
  product_id           UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,

  -- Quantités
  quantite_commandee   INTEGER NOT NULL CHECK (quantite_commandee > 0),
  quantite_confirmee   INTEGER DEFAULT 0 CHECK (quantite_confirmee >= 0),
  quantite_recue       INTEGER DEFAULT 0 CHECK (quantite_recue     >= 0),
  quantite_conforme    INTEGER DEFAULT 0 CHECK (quantite_conforme  >= 0),
  quantite_restante    INTEGER GENERATED ALWAYS AS (quantite_commandee - quantite_recue) STORED,

  -- Statut de ligne
  statut TEXT DEFAULT 'attente' CHECK (
    statut IN ('attente','confirmee','partiellement_recue','entierement_recue','non_conforme')
  ),

  -- Tarifs achat
  prix_unitaire_achat_ht  DECIMAL(10,2) NOT NULL CHECK (prix_unitaire_achat_ht >= 0),
  remise_percent          DECIMAL(5,2)  DEFAULT 0 CHECK (remise_percent BETWEEN 0 AND 100),
  prix_unitaire_achat_net DECIMAL(10,2) GENERATED ALWAYS AS
      (prix_unitaire_achat_ht * (1 - remise_percent/100)) STORED,

  -- TVA & taxes unitaires
  taux_tva                   DECIMAL(5,2) NOT NULL DEFAULT 20.0 CHECK (taux_tva BETWEEN 0 AND 100),
  eco_participation_unitaire DECIMAL(8,2) DEFAULT 0 CHECK (eco_participation_unitaire >= 0),
  taxe_deee_unitaire         DECIMAL(8,2) DEFAULT 0 CHECK (taxe_deee_unitaire         >= 0),
  taxe_emballage_unitaire    DECIMAL(8,2) DEFAULT 0 CHECK (taxe_emballage_unitaire    >= 0),
  autres_taxes_unitaires     DECIMAL(8,2) DEFAULT 0 CHECK (autres_taxes_unitaires     >= 0),

  /* Totaux achat – aucun ne référence une colonne générée */
  montant_achat_ht DECIMAL(10,2) GENERATED ALWAYS AS
      (quantite_commandee * prix_unitaire_achat_ht * (1 - remise_percent/100)) STORED,
  montant_achat_tva DECIMAL(10,2) GENERATED ALWAYS AS
      (quantite_commandee * prix_unitaire_achat_ht * (1 - remise_percent/100) * taux_tva/100) STORED,
  montant_achat_eco_participation DECIMAL(10,2) GENERATED ALWAYS AS
      (quantite_commandee * eco_participation_unitaire) STORED,
  montant_achat_taxes_unitaires   DECIMAL(10,2) GENERATED ALWAYS AS
      (quantite_commandee *
       (taxe_deee_unitaire + taxe_emballage_unitaire + autres_taxes_unitaires)) STORED,
  montant_achat_ttc DECIMAL(10,2) GENERATED ALWAYS AS
      (quantite_commandee * prix_unitaire_achat_ht * (1 - remise_percent/100) * (1 + taux_tva/100)
       + quantite_commandee *
         (eco_participation_unitaire + taxe_deee_unitaire + taxe_emballage_unitaire + autres_taxes_unitaires)
      ) STORED,

  -- Tarifs vente (facultatif)
  prix_unitaire_vente_ht  DECIMAL(10,2) DEFAULT 0,
  taux_tva_vente          DECIMAL(5,2)  DEFAULT 20.0,

  montant_vente_ht  DECIMAL(10,2) GENERATED ALWAYS AS
      (quantite_commandee * COALESCE(prix_unitaire_vente_ht,0)) STORED,
  montant_vente_ttc DECIMAL(10,2) GENERATED ALWAYS AS
      (quantite_commandee * COALESCE(prix_unitaire_vente_ht,0) * (1 + taux_tva_vente/100)) STORED,

  -- Marge
  marge_unitaire_ht DECIMAL(10,2) GENERATED ALWAYS AS
      (COALESCE(prix_unitaire_vente_ht,0) - (prix_unitaire_achat_ht * (1 - remise_percent/100))) STORED,
  marge_totale_ht   DECIMAL(10,2) GENERATED ALWAYS AS
      (quantite_commandee *
       (COALESCE(prix_unitaire_vente_ht,0) - (prix_unitaire_achat_ht * (1 - remise_percent/100)))) STORED,

  -- Prix de revient (renseignés par la fonction de répartition)
  prix_revient_unitaire_ht  DECIMAL(10,2),
  prix_revient_unitaire_ttc DECIMAL(10,2),

  -- Parts de frais globaux
  part_frais_livraison DECIMAL(10,2) DEFAULT 0,
  part_taxes_globales  DECIMAL(10,2) DEFAULT 0,

  -- Remplacement
  ligne_remplacee_id UUID REFERENCES commande_fournisseur_lignes(id),
  motif_remplacement TEXT,

  -- Dates
  date_reception_prevue  DATE,
  date_reception_reelle  TIMESTAMPTZ,

  -- Audit
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE (commande_id, product_id),
  CHECK (quantite_recue    <= quantite_commandee),
  CHECK (quantite_conforme <= quantite_recue)
);

/* Index commande_fournisseur_lignes */
CREATE INDEX IF NOT EXISTS idx_lignes_commande   ON commande_fournisseur_lignes(commande_id);
CREATE INDEX IF NOT EXISTS idx_lignes_product    ON commande_fournisseur_lignes(product_id);
CREATE INDEX IF NOT EXISTS idx_lignes_statut     ON commande_fournisseur_lignes(statut);
CREATE INDEX IF NOT EXISTS idx_lignes_reception
  ON commande_fournisseur_lignes(commande_id, statut)
  WHERE quantite_recue < quantite_commandee;

/* ----------------------------------------------------------------
   3. TABLE RELANCES : commande_relances
   ---------------------------------------------------------------- */
CREATE TABLE IF NOT EXISTS commande_relances (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commande_id     UUID NOT NULL REFERENCES commandes_fournisseur(id) ON DELETE CASCADE,

  type_relance TEXT NOT NULL CHECK (
    type_relance IN ('confirmation','livraison','retard','litige','facturation')
  ),

  date_relance        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  canal               TEXT NOT NULL CHECK (canal IN ('email','telephone','courrier','visite')),

  destinataire_nom       TEXT,
  destinataire_email     TEXT,
  destinataire_telephone TEXT,

  objet              TEXT NOT NULL,
  message            TEXT NOT NULL,
  pieces_jointes     JSONB,

  reponse_recue      BOOLEAN DEFAULT FALSE,
  date_reponse       TIMESTAMPTZ,
  contenu_reponse    TEXT,

  created_by         UUID NOT NULL REFERENCES auth.users(id),
  created_at         TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_relances_commande   ON commande_relances(commande_id);
CREATE INDEX IF NOT EXISTS idx_relances_type_date  ON commande_relances(type_relance, date_relance);

/* ================================================================
   Fin de la PARTIE 1  – Schéma des tables (aucune erreur 42P17)
   ============================================================== */
/* ==================================================================
   10_commandes_fournisseurs.sql
   PART 2 / 3 : fonctions métier, répartition & triggers
   ================================================================== */

/* ---------- 1. Génération de numéro & création commande ---------- */
CREATE OR REPLACE FUNCTION creer_commande_fournisseur(
  p_fournisseur_id        UUID,
  p_commandeur_id         UUID,
  p_date_livraison_souhaitee DATE DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
  new_id         UUID;
  compteur       INTEGER;
  numero_commande TEXT;
BEGIN
  SELECT COALESCE(MAX(CAST (substring(numero_commande FROM '-(\\d+)$') AS INTEGER)),0)+1
  INTO   compteur
  FROM   commandes_fournisseur
  WHERE  numero_commande ~ ('^CMD-FOUR-'||extract(year from current_date)||'-\\d+$');

  numero_commande := format('CMD-FOUR-%s-%s',
                            extract(year from current_date),
                            lpad(compteur::text,3,'0'));

  INSERT INTO commandes_fournisseur(
      numero_commande, fournisseur_id, commandeur_id, date_livraison_souhaitee
  ) VALUES (numero_commande, p_fournisseur_id, p_commandeur_id, p_date_livraison_souhaitee)
  RETURNING id INTO new_id;

  RETURN new_id;
END;
$$ LANGUAGE plpgsql;

/* ---------- 2. Ajout ligne (corrigé – pas de quantite_restante) ---------- */
CREATE OR REPLACE FUNCTION ajouter_ligne_commande(
  p_commande_id        UUID,
  p_product_id         UUID,
  p_quantite           INTEGER,
  p_prix_achat_ht      DECIMAL(10,2),
  p_prix_vente_ht      DECIMAL(10,2) DEFAULT NULL,
  p_taux_tva           DECIMAL(5,2)  DEFAULT NULL,
  p_eco_participation  DECIMAL(8,2)  DEFAULT 0,
  p_taxe_deee          DECIMAL(8,2)  DEFAULT 0
) RETURNS UUID AS $$
DECLARE
  ligne_id    UUID;
  tva_produit DECIMAL(5,2);
BEGIN
  IF p_taux_tva IS NULL THEN
    SELECT COALESCE(taux_tva_standard,20.0) INTO tva_produit
    FROM products WHERE id = p_product_id;
  ELSE
    tva_produit := p_taux_tva;
  END IF;

  INSERT INTO commande_fournisseur_lignes(
      commande_id, product_id, quantite_commandee,
      prix_unitaire_achat_ht, prix_unitaire_vente_ht,
      taux_tva, eco_participation_unitaire, taxe_deee_unitaire
  ) VALUES (
      p_commande_id, p_product_id, p_quantite,
      p_prix_achat_ht, p_prix_vente_ht,
      tva_produit, p_eco_participation, p_taxe_deee
  ) RETURNING id INTO ligne_id;

  RETURN ligne_id;
END;
$$ LANGUAGE plpgsql;

/* ---------- 3. Répartition configurable frais + taxes ---------- */
CREATE OR REPLACE FUNCTION repartir_frais_commande(p_commande_id UUID)
RETURNS boolean AS $$
DECLARE
  c        commandes_fournisseur%ROWTYPE;
  l        RECORD;
  tot_qte  INTEGER;
  tot_poids DECIMAL(10,4);
  tot_val  DECIMAL(12,2);
  fp_u     DECIMAL(10,4);  fp_kg DECIMAL(10,4);  fp_val DECIMAL(10,6);
  tp_u     DECIMAL(10,4);  tp_kg DECIMAL(10,4);  tp_val DECIMAL(10,6);
BEGIN
  SELECT * INTO c FROM commandes_fournisseur WHERE id = p_commande_id;
  IF NOT FOUND THEN RETURN false; END IF;

  SELECT COALESCE(sum(q.quantite_commandee),0),
         COALESCE(sum(q.quantite_commandee*COALESCE(p.poids_kg,1)),0),
         COALESCE(sum(q.montant_achat_ht),0)
  INTO   tot_qte, tot_poids, tot_val
  FROM   commande_fournisseur_lignes q
  LEFT JOIN products p ON p.id = q.product_id
  WHERE  q.commande_id = p_commande_id;

  IF tot_qte = 0 THEN RETURN true; END IF;

  -- Frais livraison
  CASE c.methode_repartition_livraison
    WHEN 'unite' THEN fp_u := c.frais_livraison / tot_qte;
    WHEN 'poids' THEN fp_kg:= CASE WHEN tot_poids>0 THEN c.frais_livraison/tot_poids END;
    WHEN 'valeur' THEN fp_val:= CASE WHEN tot_val>0 THEN c.frais_livraison/tot_val END;
  END CASE;

  -- Taxes globales
  CASE c.methode_repartition_taxes
    WHEN 'unite' THEN tp_u := c.taxes_globales / tot_qte;
    WHEN 'poids' THEN tp_kg:= CASE WHEN tot_poids>0 THEN c.taxes_globales/tot_poids END;
    WHEN 'valeur' THEN tp_val:= CASE WHEN tot_val>0 THEN c.taxes_globales/tot_val END;
  END CASE;

  FOR l IN
    SELECT q.*, COALESCE(p.poids_kg,1) AS poids_u
    FROM   commande_fournisseur_lignes q
    LEFT   JOIN products p ON p.id = q.product_id
    WHERE  q.commande_id = p_commande_id
  LOOP
    UPDATE commande_fournisseur_lignes
    SET part_frais_livraison = CASE c.methode_repartition_livraison
                                  WHEN 'unite'  THEN l.quantite_commandee*fp_u
                                  WHEN 'poids'  THEN l.quantite_commandee*l.poids_u*fp_kg
                                  WHEN 'valeur' THEN l.montant_achat_ht*fp_val END,
        part_taxes_globales  = CASE c.methode_repartition_taxes
                                  WHEN 'unite'  THEN l.quantite_commandee*tp_u
                                  WHEN 'poids'  THEN l.quantite_commandee*l.poids_u*tp_kg
                                  WHEN 'valeur' THEN l.montant_achat_ht*tp_val END,
        prix_revient_unitaire_ht =
            l.prix_unitaire_achat_net
          + CASE c.methode_repartition_livraison
              WHEN 'unite'  THEN fp_u
              WHEN 'poids'  THEN l.poids_u*fp_kg
              WHEN 'valeur' THEN l.prix_unitaire_achat_net*fp_val END
          + CASE c.methode_repartition_taxes
              WHEN 'unite'  THEN tp_u
              WHEN 'poids'  THEN l.poids_u*tp_kg
              WHEN 'valeur' THEN l.prix_unitaire_achat_net*tp_val END,
        prix_revient_unitaire_ttc =
            (l.prix_unitaire_achat_net
             + CASE c.methode_repartition_livraison
                 WHEN 'unite'  THEN fp_u
                 WHEN 'poids'  THEN l.poids_u*fp_kg
                 WHEN 'valeur' THEN l.prix_unitaire_achat_net*fp_val END
             + CASE c.methode_repartition_taxes
                 WHEN 'unite'  THEN tp_u
                 WHEN 'poids'  THEN l.poids_u*tp_kg
                 WHEN 'valeur' THEN l.prix_unitaire_achat_net*tp_val END)
            * (1 + l.taux_tva/100)
          + l.eco_participation_unitaire + l.taxe_deee_unitaire
          + l.taxe_emballage_unitaire   + l.autres_taxes_unitaires
    WHERE id = l.id;
  END LOOP;

  RETURN true;
END;
$$ LANGUAGE plpgsql;

/* ---------- 4. Validation commande ---------- */
CREATE OR REPLACE FUNCTION valider_commande_fournisseur(
  p_commande_id UUID, p_validateur_id UUID
) RETURNS boolean AS $$
BEGIN
  UPDATE commandes_fournisseur
     SET statut='validee', validateur_id=p_validateur_id,
         date_validation=now()
   WHERE id = p_commande_id AND statut='brouillon';
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

/* ---------- 5. Recalcul totaux (trigger) ---------- */
CREATE OR REPLACE FUNCTION trg_update_commande_totaux() RETURNS trigger AS $$
DECLARE cmd UUID;
BEGIN
  cmd := COALESCE(NEW.commande_id, OLD.commande_id);

  UPDATE commandes_fournisseur SET
    total_achat_ht = (SELECT COALESCE(sum(montant_achat_ht),0) FROM commande_fournisseur_lignes WHERE commande_id=cmd),
    total_tva      = (SELECT COALESCE(sum(montant_achat_tva),0) FROM commande_fournisseur_lignes WHERE commande_id=cmd),
    total_eco_participation = (SELECT COALESCE(sum(montant_achat_eco_participation),0) FROM commande_fournisseur_lignes WHERE commande_id=cmd),
    total_taxes_unitaires   = (SELECT COALESCE(sum(montant_achat_taxes_unitaires),0) FROM commande_fournisseur_lignes WHERE commande_id=cmd),
    total_vente_theorique_ht  = (SELECT COALESCE(sum(montant_vente_ht),0) FROM commande_fournisseur_lignes WHERE commande_id=cmd),
    total_vente_theorique_ttc = (SELECT COALESCE(sum(montant_vente_ttc),0) FROM commande_fournisseur_lignes WHERE commande_id=cmd),
    total_achat_ttc =
       (SELECT COALESCE(sum(montant_achat_ttc),0) FROM commande_fournisseur_lignes WHERE commande_id=cmd)
       + COALESCE(frais_livraison,0) + COALESCE(taxes_globales,0),
    nb_lignes = (SELECT count(*) FROM commande_fournisseur_lignes WHERE commande_id=cmd),
    nb_references = (SELECT count(DISTINCT product_id) FROM commande_fournisseur_lignes WHERE commande_id=cmd),
    quantite_totale_elements = (SELECT COALESCE(sum(quantite_commandee),0) FROM commande_fournisseur_lignes WHERE commande_id=cmd),
    updated_at = now()
  WHERE id = cmd;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_commande_totaux ON commande_fournisseur_lignes;
CREATE TRIGGER trg_update_commande_totaux
AFTER INSERT OR UPDATE OR DELETE
ON commande_fournisseur_lignes
FOR EACH ROW EXECUTE FUNCTION trg_update_commande_totaux();

/* ---------- 6. Répartition auto si frais changent ---------- */
CREATE OR REPLACE FUNCTION trg_repartir_frais_cfg() RETURNS trigger AS $$
BEGIN
  IF (OLD.frais_livraison IS DISTINCT FROM NEW.frais_livraison)
     OR (OLD.taxes_globales IS DISTINCT FROM NEW.taxes_globales)
     OR (OLD.methode_repartition_livraison IS DISTINCT FROM NEW.methode_repartition_livraison)
     OR (OLD.methode_repartition_taxes     IS DISTINCT FROM NEW.methode_repartition_taxes) THEN
       PERFORM repartir_frais_commande(NEW.id);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_repartir_frais_cfg ON commandes_fournisseur;
CREATE TRIGGER trg_repartir_frais_cfg
AFTER UPDATE ON commandes_fournisseur
FOR EACH ROW EXECUTE FUNCTION trg_repartir_frais_cfg();
/* ---------- 3. Données de test (seed) ---------- */
DO $$
DECLARE
  v_user_id uuid;
BEGIN
  -- récupère n’importe quel utilisateur Auth (le premier suffit pour la démo)
  SELECT id INTO v_user_id FROM auth.users LIMIT 1;

  IF v_user_id IS NULL THEN
    RAISE NOTICE '⏩ Pas de user lisible : on saute le seed commandes_fournisseur.';
    RETURN;
  END IF;

  -- insère la commande de test si la table est encore vide
  IF NOT EXISTS (SELECT 1 FROM commandes_fournisseur) THEN
    INSERT INTO commandes_fournisseur (
      numero_commande,
      fournisseur_id,
      commandeur_id,
      statut,
      date_livraison_souhaitee,
      frais_livraison,
      taxes_globales,
      methode_repartition_livraison,
      methode_repartition_taxes
    )
    VALUES (
      'CMD-FOUR-' || extract(year from current_date) || '-001',
      (SELECT id FROM partenaires WHERE type_partenaire = 'fournisseur' LIMIT 1),
      v_user_id,                 -- ← utilisateur Auth existant
      'brouillon',
      current_date + 14,
      50.00,
      25.00,
      'unite',
      'valeur'
    );

    RAISE NOTICE '✅ Seed commandes_fournisseur insérée (user %).', v_user_id;
  ELSE
    RAISE NOTICE 'ℹ️ La table commandes_fournisseur contient déjà des données : seed ignoré.';
  END IF;
END;
$$ LANGUAGE plpgsql;

