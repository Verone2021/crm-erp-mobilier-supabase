import { useState, useEffect } from 'react'
import { useRouter } from 'next/router'
import { supabase } from '../../../frontend/lib/supabaseClient'

export default function EditPartenaire() {
  const router = useRouter()
  const { id } = router.query
  const [form, setForm] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!id) return
    supabase
      .from('partenaires')
      .select('*')
      .eq('id', id)
      .single()
      .then(({ data, error }) => {
        if (error) console.error(error)
        else setForm(data)
        setLoading(false)
      })
  }, [id])

  const handleChange = e => {
    const { name, value, type, checked } = e.target
    setForm(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }))
  }

  const handleSave = async () => {
    setSaving(true)
    const { error } = await supabase
      .from('partenaires')
      .update(form)
      .eq('id', id)
    if (error) console.error(error)
    else router.push('/partenaires')
  }

  if (loading) return <div className="p-4">Chargement…</div>
  if (!form) return <div className="p-4">Aucun partenaire trouvé.</div>

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-xl font-semibold mb-4">Modifier partenaire</h1>
      <div className="space-y-4">
        <div>
          <label className="block mb-1">Nom complet</label>
          <input
            name="nom_complet"
            value={form.nom_complet || ''}
            onChange={handleChange}
            className="w-full border p-2 rounded"
          />
        </div>
        <div>
          <label className="block mb-1">Email</label>
          <input
            type="email"
            name="email"
            value={form.email || ''}
            onChange={handleChange}
            className="w-full border p-2 rounded"
          />
        </div>
        <div>
          <label className="block mb-1">Téléphone</label>
          <input
            name="telephone"
            value={form.telephone || ''}
            onChange={handleChange}
            className="w-full border p-2 rounded"
          />
        </div>
        <div className="flex items-center">
          <input
            type="checkbox"
            name="is_active"
            checked={form.is_active}
            onChange={handleChange}
            id="isActiveEdit"
          />
          <label htmlFor="isActiveEdit" className="ml-2">
            Actif
          </label>
        </div>
        <button
          onClick={handleSave}
          disabled={saving}
          className="px-4 py-2 bg-green-600 text-white rounded"
        >
          {saving ? 'Sauvegarde…' : 'Sauvegarder'}
        </button>
      </div>
    </div>
  )
}
