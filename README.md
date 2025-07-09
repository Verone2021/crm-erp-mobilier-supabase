🏢 CRM/ERP Mobilier & Décoration - ICE MOB

Système de gestion complet pour le secteur mobilier, construit avec Supabase et Next.js

📊 Architecture Actuelle
✅ Base de Données Complète (Juillet 2025)

24 tables structurées (140K de données)
Schema complet sauvegardé dans supabase/migrations/
Modules opérationnels : clients, produits, commandes, stock, tarifs, promotions
Prêt pour développement frontend avec Windsurf

🏗️ Structure Validée
📊 Architecture CRM/ERP ICE MOB:
├── 👥 Gestion Clients & Partenaires
├── 📦 Catalogue Produits (Hiérarchie complète)
├── 🛒 Commandes Fournisseurs & Clients  
├── 📋 Gestion Stock & Mouvements
├── 💰 Tarification & Promotions
└── 🔐 Sécurité RLS & Audit

🎯 Description du Projet
Application CRM/ERP complète dédiée au secteur mobilier et décoration, offrant une gestion intégrée de :
✨ Modules Fonctionnels
ModuleStatutDescription🛒 Achats✅ OpérationnelCommandes fournisseur, réceptions, relances automatiques📦 Stock✅ OpérationnelGestion temps réel, alertes seuils, mouvements traçables💰 Ventes✅ OpérationnelCommandes clients, tarifs négociés, promotions👥 CRM✅ OpérationnelPartenaires (clients/fournisseurs), contacts multiples📊 Analytics🚧 En développementTableaux de bord, alertes métier, rapports automatisés
🎨 Interfaces Prévues

Interface Admin : Gestion complète pour l'équipe ICE MOB (à développer avec Windsurf)
Portail Client B2B : Commandes et tarifs pour professionnels
Site Client B2C : Catalogue public pour particuliers
API REST : Intégrations tierces (Packlink, Abby, Stripe)


🏗️ Stack Technique
Backend Supabase (✅ Complet)
mermaidgraph TB
    subgraph "Base de Données"
        A[PostgreSQL 15]
        B[24 Tables Structurées]
        C[Row Level Security]
        D[Real-time Subscriptions]
    end
    
    subgraph "Modules Métier"
        E[Gestion Clients]
        F[Catalogue Produits]
        G[Commandes & Stock]
        H[Tarification]
    end
    
    A --> B
    B --> C
    C --> D
    B --> E
    B --> F
    B --> G
    B --> H
Frontend (🚧 À développer avec Windsurf)

Next.js 15 + React 19 + TypeScript
TailwindCSS + shadcn/ui pour le design
TanStack Query v5 pour la gestion d'état
Supabase Client pour l'API automatique


📊 Base de Données Détaillée
Architecture Complète (24 Tables)
DomaineTablesDescriptionUtilisateursauth.users, user_profilesAuthentification et profils étendusCataloguefamilles, categories, sous_categories, product_groups, productsHiérarchie produits à 5 niveauxPartenairespartenaires, contacts_partenairesClients, fournisseurs, contacts B2BAchatscommandes_fournisseur, commande_fournisseur_lignes, commande_relancesWorkflow achats completStockwarehouses, mouvements_stock, logs_stockGestion stock temps réelVentescommandes_client, commande_client_lignesProcessus vente intégréTarificationtarifs_clients_quantites, promotionsGrilles tarifaires flexiblesAssetsproduct_images, entity_urlsMédias et liens polymorphes
Workflows Automatisés

Réception Fournisseur → Mise à jour stock automatique
Commande Client → Vérification stock + réservation
Seuils Stock → Alertes + suggestions réapprovisionnement
Tarification → Résolution prix par règles de priorité


🚀 Installation & Configuration
Prérequis
bash# Versions requises
node >= 18.0.0
npm >= 9.0.0
git >= 2.30.0
Installation
bash# 1. Cloner le projet
git clone https://github.com/Verone2021/crm-erp-mobilier-supabase.git
cd crm-erp-mobilier-supabase

# 2. Installer Supabase CLI
npm install -g @supabase/cli

# 3. Se connecter au projet
supabase login
supabase link --project-ref tyqruipiblvgdqfoghmw
Variables d'environnement
env# .env.local
NEXT_PUBLIC_SUPABASE_URL=https://tyqruipiblvgdqfoghmw.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
NODE_ENV=development

💻 Développement avec Windsurf
Étapes Recommandées

Phase 1 : Interface admin avec dashboard principal
Phase 2 : Modules CRUD (clients, produits, commandes)
Phase 3 : Tableaux de bord et analytics
Phase 4 : Interface client et portail B2B

Prompt Windsurf Optimisé
J'ai un projet Supabase CRM/ERP complet avec :
- 24 tables structurées (clients, produits, commandes, stock)
- Schema sauvegardé dans supabase/migrations/00_Backup_Schema_Complete.sql
- Row Level Security configuré
- Base de 140K de données opérationnelles

Je veux créer l'interface admin avec :
- Next.js 15 + React 19 + TypeScript
- TailwindCSS + shadcn/ui pour le design
- TanStack Query pour la gestion d'état
- Connexion Supabase complète

Peux-tu initialiser le projet frontend et créer un dashboard admin qui affiche les KPIs depuis ma base ?

📈 Roadmap
✅ Phase 1 : Backend (Terminé - Juillet 2025)

Architecture base de données complète (24 tables)
Système authentification + RLS
Modules métier principaux
Workflows automatisés

🚧 Phase 2 : Frontend Admin (En cours)

 Dashboard principal + KPIs
 Interface commandes fournisseur
 Gestion stock + alertes
 Interface commandes client
 Tests e2e

📅 Phase 3 : Frontend Client (Q4 2025)

 Catalogue public B2C
 Tunnel commande optimisé
 Espace client personnalisé
 Portail B2B professionnel

📅 Phase 4 : Intégrations (Q1 2026)

 Packlink (expéditions automatiques)
 Abby (facturation automatique)
 Stripe (paiements en ligne)
 Metabase (BI avancée)


🔒 Sécurité
Row Level Security (RLS)
Système hiérarchique basé sur les rôles utilisateurs :
RôleAccèsPermissionsadminCompletToutes opérationsmanagerMétierGestion + lectureacheteurAchats + StockCommandes fournisseurcommercialVentesCommandes clientcomptableLecture seuleConsultation uniquement

📊 Métriques de Performance
Objectifs 2025
MétriqueCibleActuelArchitecture Backend✅ Complet✅ 24 tables opérationnellesDonnées de test✅ Disponible✅ 140K de donnéesFrontend AdminQ4 2025🚧 En développementTemps traitement commande-50%🎯 Objectif avec automatisation

🤝 Contribution
Getting Started

Fork le projet
Clone votre fork
Créer une branche feature (git checkout -b feature/nouvelle-fonctionnalite)
Commit vos changements (git commit -m 'Ajout nouvelle fonctionnalité')
Push vers la branche (git push origin feature/nouvelle-fonctionnalite)
Ouvrir une Pull Request


📞 Support & Liens
Projet

Repository : GitHub
Supabase Dashboard : Projet ICE MOB
Documentation : Voir fichiers /docs et /supabase/migrations

Technologies

Supabase : Documentation
Next.js 15 : Guide de migration
Windsurf : Guide d'utilisation


📄 Licence
Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.

🎉 Remerciements

Supabase pour l'infrastructure backend exceptionnelle
Communauté open source pour les outils et libraries utilisés
Équipe ICE MOB pour les spécifications métier


Dernière mise à jour : 9 juillet 2025
Version : 2.0.0 (Backend complet)
Statut : ✅ Backend opérationnel | 🚧 Frontend en développement
Prochaine étape : Développement interface admin avec Windsurf 🚀
