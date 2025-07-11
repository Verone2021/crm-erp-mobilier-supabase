import { z } from 'zod';

export type Partenaire = {
  id: string;
  type_partenaire: string;
  prenom?: string;
  nom?: string;
  sexe?: string;
  denomination_sociale?: string;
  nom_commercial?: string;
  siret?: string;
  email?: string;
  telephone?: string;
  adresse?: string;
  code_postal?: string;
  ville?: string;
  pays?: string;
  adresse_livraison?: string;
  ville_livraison?: string;
  code_postal_livraison?: string;
  pays_livraison?: string;
  segment_industrie?: string;
  conditions_paiement?: string;
  taux_tva?: number;
  langue: string;
  timezone: string;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  nom_complet?: string;
};

export const partenaireSchema = z.object({
  id: z.string().uuid().optional(),
  type_partenaire: z.string(),
  prenom: z.string().optional(),
  nom: z.string().optional(),
  sexe: z.string().optional(),
  denomination_sociale: z.string().optional(),
  nom_commercial: z.string().optional(),
  siret: z.string().length(14).optional(),
  email: z.string().email().optional(),
  telephone: z.string().optional(),
  adresse: z.string().optional(),
  code_postal: z.string().optional(),
  ville: z.string().optional(),
  pays: z.string().optional(),
  adresse_livraison: z.string().optional(),
  ville_livraison: z.string().optional(),
  code_postal_livraison: z.string().optional(),
  pays_livraison: z.string().optional(),
  segment_industrie: z.string().optional(),
  conditions_paiement: z.string().optional(),
  taux_tva: z.number().optional(),
  langue: z.string().length(2).default('fr'),
  timezone: z.string().default('Europe/Paris'),
  is_active: z.boolean().default(true),
});

export type PartenaireFormData = z.infer<typeof partenaireSchema>;

export type PartenaireFilter = {
  search?: string;
  type?: string;
  status?: boolean;
  segment_industrie?: string;
  pays?: string;
};
