import { useEffect, useState } from 'react'
import Link from 'next/link'
import { supabase } from '../../../frontend/lib/supabaseClient'

export default function PartenairesList() {
  const [data, setData] = useState([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    const fetchPartenaires = async () => {
      const { data: partners, error } = await supabase
        .from('partenaires')
        .select('*')
        .order('created_at', { ascending: false })
      if (error) console.error(error)
      else setData(partners)
      setLoading(false)
    }
    fetchPartenaires()
  }, [])

  if (loading) return <div className="p-4">Chargement…</div>

  return (
    <div className="p-4">
      <div className="flex justify-between items-center mb-4">
        <h1 className="text-2xl font-semibold">Partenaires</h1>
        <Link href="/partenaires/new">
          <button className="px-4 py-2 bg-blue-600 text-white rounded">
            + Nouveau
          </button>
        </Link>
      </div>

      <table className="min-w-full bg-white shadow rounded">
        <thead>
          <tr className="bg-gray-100">
            <th className="p-2 text-left">Nom</th>
            <th className="p-2 text-left">Email</th>
            <th className="p-2 text-left">Téléphone</th>
            <th className="p-2 text-left">Actif</th>
            <th className="p-2 text-left">Actions</th>
          </tr>
        </thead>
        <tbody>
          {data.map(p => (
            <tr key={p.id} className="border-t">
              <td className="p-2">{p.nom_complet}</td>
              <td className="p-2">{p.email}</td>
              <td className="p-2">{p.telephone}</td>
              <td className="p-2">
                {p.is_active ? '✅' : '❌'}
              </td>
              <td className="p-2">
                <Link href={`/partenaires/${p.id}`}>
                  <button className="px-2 py-1 bg-green-500 text-white rounded">
                    Voir / Éditer
                  </button>
                </Link>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
