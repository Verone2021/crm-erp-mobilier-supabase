
## 🛡️ Sauvegardes

### Dernière sauvegarde complète
- **Date :** 2025-07-07
- **Migrations :** 15 fichiers SQL versionnés
- **Localisation :** `supabase/migrations/`
- **Méthode :** Un fichier SQL par table/fonction, sauvegardé en local et sur GitHub

### Historique des backups
- `supabase/backups/backup_full.sql` : Backup global SQL (optionnel)
- `supabase/migrations/` : Migrations individuelles (recommandé pour CI/CD et restauration rapide)
# CRM/ERP Mobilier & Décoration - Supabase

## 📋 Description
Application CRM/ERP complète pour le secteur mobilier et décoration, construite avec Supabase.

## 🏗️ Architecture
- **Backend :** Supabase (PostgreSQL + API REST + Auth)
- **Base de données :** 17 tables principales
- **Domaine :** Gestion complète partenaires, produits, commandes

## 📊 Structure de la Base de Données

### Tables Principales
- `partenaires` - Fournisseurs, clients, contacts (17 champs)
- `products` - Catalogue produits mobilier (35 champs)
- `categories`, `sous_categories`, `familles` - Hiérarchie produits
- `user_profiles`, `utilisateurs` - Gestion utilisateurs
- `contacts_partenaires` - Réseau de contacts

## 🛡️ Sauvegardes

### Dernière sauvegarde complète
- **Date :** 2024-07-02
- **Tables :** 17 tables sauvegardées
- **Format :** JSON + SQL
- **Localisation :** `supabase/backups/`

## 📝 Changelog

### 2024-07-02
- ✅ Sauvegarde complète schéma initial
- ✅ Création repository GitHub
- ✅ Documentation automatisée
- 🔄 Préparation script commandes fournisseurs

## 🚀 Prochaines Étapes
- [ ] Script 10_commandes_fournisseurs.sql
- [ ] Module gestion commandes
- [ ] Workflows automatisés

---
*Généré automatiquement le 2024-07-02*
