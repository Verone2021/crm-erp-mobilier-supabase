import { useState } from 'react'
import { useRouter } from 'next/router'
import { supabase } from '../../../frontend/lib/supabaseClient'

export default function NewPartenaire() {
  const router = useRouter()
  const [form, setForm] = useState({
    nom_complet: '',
    email: '',
    telephone: '',
    is_active: true
  })
  const [submitting, setSubmitting] = useState(false)

  const handleChange = e => {
    const { name, value, type, checked } = e.target
    setForm(prev => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value
    }))
  }

  const handleSubmit = async e => {
    e.preventDefault()
    setSubmitting(true)
    const { error } = await supabase
      .from('partenaires')
      .insert([form])
    if (error) {
      console.error(error)
      setSubmitting(false)
    } else {
      router.push('/partenaires')
    }
  }

  return (
    <div className="p-4 max-w-md mx-auto">
      <h1 className="text-xl font-semibold mb-4">Nouveau partenaire</h1>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block mb-1">Nom complet</label>
          <input
            name="nom_complet"
            value={form.nom_complet}
            onChange={handleChange}
            className="w-full border p-2 rounded"
            required
          />
        </div>
        <div>
          <label className="block mb-1">Email</label>
          <input
            type="email"
            name="email"
            value={form.email}
            onChange={handleChange}
            className="w-full border p-2 rounded"
            required
          />
        </div>
        <div>
          <label className="block mb-1">Téléphone</label>
          <input
            name="telephone"
            value={form.telephone}
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
            id="isActive"
          />
          <label htmlFor="isActive" className="ml-2">
            Actif
          </label>
        </div>
        <button
          type="submit"
          disabled={submitting}
          className="px-4 py-2 bg-blue-600 text-white rounded"
        >
          {submitting ? 'Enregistrement…' : 'Créer'}
        </button>
      </form>
    </div>
  )
}
