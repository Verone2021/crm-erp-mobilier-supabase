import { supabase } from '@/lib/supabase';
import { Partenaire, PartenaireFormData, PartenaireFilter } from '@/lib/types/partenaires';

export const partenairesService = {
  async list(filter?: PartenaireFilter) {
    let query = supabase
      .from('partenaires')
      .select('*')
      .order('created_at', { ascending: false });

    if (filter?.search) {
      query = query.ilike('nom_complet', `%${filter.search}%`);
    }
    if (filter?.type) {
      query = query.eq('type_partenaire', filter.type);
    }
    if (filter?.status !== undefined) {
      query = query.eq('is_active', filter.status);
    }
    if (filter?.segment_industrie) {
      query = query.eq('segment_industrie', filter.segment_industrie);
    }
    if (filter?.pays) {
      query = query.eq('pays', filter.pays);
    }

    const { data, error } = await query;
    if (error) throw error;
    return data as Partenaire[];
  },

  async get(id: string) {
    const { data, error } = await supabase
      .from('partenaires')
      .select('*')
      .eq('id', id)
      .single();

    if (error) throw error;
    return data as Partenaire;
  },

  async create(data: PartenaireFormData) {
    // Calcul du nom_complet si non fourni
    const nomComplet = data.prenom && data.nom 
      ? `${data.prenom} ${data.nom}`
      : data.denomination_sociale || data.nom_commercial;

    const { data: createdData, error } = await supabase
      .from('partenaires')
      .insert([
        {
          ...data,
          nom_complet: nomComplet,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        }
      ])
      .select('*')
      .single();

    if (error) throw error;
    return createdData as Partenaire;
  },

  async update(id: string, data: Partial<PartenaireFormData>) {
    // Calcul du nom_complet si prenom ou nom sont modifiés
    const currentPartenaire = await partenairesService.get(id);
    const nomComplet = (data.prenom || currentPartenaire.prenom) && (data.nom || currentPartenaire.nom)
      ? `${data.prenom || currentPartenaire.prenom} ${data.nom || currentPartenaire.nom}`
      : data.denomination_sociale || currentPartenaire.denomination_sociale || 
        data.nom_commercial || currentPartenaire.nom_commercial;

    const { data: updatedData, error } = await supabase
      .from('partenaires')
      .update({
        ...data,
        nom_complet: nomComplet,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select('*')
      .single();

    if (error) throw error;
    return updatedData as Partenaire;
  },

  async delete(id: string) {
    const { error } = await supabase
      .from('partenaires')
      .delete()
      .eq('id', id);

    if (error) throw error;
  },

  async count(filter?: PartenaireFilter) {
    let query = supabase
      .from('partenaires')
      .select('*', { count: 'exact', head: true });

    if (filter?.search) {
      query = query.ilike('nom_complet', `%${filter.search}%`);
    }
    if (filter?.type) {
      query = query.eq('type_partenaire', filter.type);
    }
    if (filter?.status !== undefined) {
      query = query.eq('is_active', filter.status);
    }
    if (filter?.segment_industrie) {
      query = query.eq('segment_industrie', filter.segment_industrie);
    }
    if (filter?.pays) {
      query = query.eq('pays', filter.pays);
    }

    const { count, error } = await query;
    if (error) throw error;
    return count;
  },
};
