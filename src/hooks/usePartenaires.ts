import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Partenaire, PartenaireFormData, PartenaireFilter } from '@/lib/types/partenaires';
import { partenairesService } from '@/lib/database/partenaires';

export function usePartenaires(filter?: PartenaireFilter) {
  return useQuery({
    queryKey: ['partenaires', filter],
    queryFn: () => partenairesService.list(filter),
    staleTime: 1000 * 60 * 5, // 5 minutes
  });
}

export function usePartenaire(id: string) {
  return useQuery({
    queryKey: ['partenaire', id],
    queryFn: () => partenairesService.get(id),
    enabled: !!id,
  });
}

export function useCreatePartenaire() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: PartenaireFormData) => partenairesService.create(data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partenaires'] });
    },
  });
}

export function useUpdatePartenaire() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (data: { id: string; data: Partial<PartenaireFormData> }) =>
      partenairesService.update(data.id, data.data),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partenaires'] });
    },
  });
}

export function useDeletePartenaire() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (id: string) => partenairesService.delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['partenaires'] });
    },
  });
}

export function usePartenairesCount(filter?: PartenaireFilter) {
  return useQuery({
    queryKey: ['partenaires-count', filter],
    queryFn: () => partenairesService.count(filter),
    staleTime: 1000 * 60 * 5, // 5 minutes
  });
}
