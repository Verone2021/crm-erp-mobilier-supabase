'use client'

import { useEffect, useState } from 'react'
import { supabase } from '../../lib/supabase'
import Link from 'next/link'

interface Partenaire {
  id: string
  nom_complet: string
  email: string
  telephone?: string
  is_active: boolean
  created_at: string
}

export default function PartenairesPage() {
  const [partenaires, setPartenaires] = useState<Partenaire[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [showForm, setShowForm] = useState(false)
  const [formData, setFormData] = useState({
    nom_complet: '',
    email: '',
    telephone: '',
    is_active: true
  })
  const [submitting, setSubmitting] = useState(false)

  // Charger les partenaires
  useEffect(() => {
    loadPartenaires()
  }, [])

  async function loadPartenaires() {
    try {
      setLoading(true)
      setError(null)
      
      const { data, error } = await supabase
        .from('partenaires')
        .select('*')
        .order('created_at', { ascending: false })

      if (error) throw error
      setPartenaires(data || [])
    } catch (err: any) {
      setError(err.message)
      console.error('Erreur lors du chargement:', err)
    } finally {
      setLoading(false)
    }
  }

  // Ajouter un partenaire
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault()
    
    try {
      setSubmitting(true)
      setError(null)
      
      const { error } = await supabase
        .from('partenaires')
        .insert([formData])

      if (error) throw error

      // Reset form et recharger
      setFormData({ nom_complet: '', email: '', telephone: '', is_active: true })
      setShowForm(false)
      await loadPartenaires()
    } catch (err: any) {
      setError(err.message)
    } finally {
      setSubmitting(false)
    }
  }

  // Supprimer un partenaire
  async function deletePartenaire(id: string, nom: string) {
    if (!confirm(`Êtes-vous sûr de vouloir supprimer "${nom}" ?`)) return

    try {
      setError(null)
      const { error } = await supabase
        .from('partenaires')
        .delete()
        .eq('id', id)

      if (error) throw error
      await loadPartenaires()
    } catch (err: any) {
      setError(err.message)
    }
  }

  // Activer/désactiver un partenaire
  async function toggleActive(id: string, currentStatus: boolean) {
    try {
      setError(null)
      const { error } = await supabase
        .from('partenaires')
        .update({ is_active: !currentStatus })
        .eq('id', id)

      if (error) throw error
      await loadPartenaires()
    } catch (err: any) {
      setError(err.message)
    }
  }

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white shadow">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex items-center">
              <Link href="/" className="text-blue-600 hover:text-blue-800 mr-4 font-medium">
                ← Retour au dashboard
              </Link>
              <h1 className="text-xl font-semibold text-gray-900">
                🤝 Gestion des Partenaires
              </h1>
            </div>
            <div className="flex items-center space-x-3">
              <span className="text-sm text-gray-500">
                {partenaires.length} partenaire(s)
              </span>
              <button
                onClick={() => setShowForm(!showForm)}
                className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium transition-colors"
              >
                {showForm ? 'Annuler' : '+ Nouveau Partenaire'}
              </button>
            </div>
          </div>
        </div>
      </div>

      <div className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        
        {/* Messages d'erreur */}
        {error && (
          <div className="bg-red-50 border border-red-200 rounded-md p-4 mb-6">
            <div className="flex">
              <div className="flex-shrink-0">
                <svg className="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
                  <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clipRule="evenodd" />
                </svg>
              </div>
              <div className="ml-3">
                <h3 className="text-sm font-medium text-red-800">
                  Erreur
                </h3>
                <div className="mt-2 text-sm text-red-700">
                  {error}
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Formulaire de création */}
        {showForm && (
          <div className="bg-white shadow rounded-lg mb-6 p-6">
            <h3 className="text-lg font-medium text-gray-900 mb-4">
              ➕ Nouveau Partenaire
            </h3>
            <form onSubmit={handleSubmit} className="space-y-4">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Nom complet *
                  </label>
                  <input
                    type="text"
                    required
                    value={formData.nom_complet}
                    onChange={(e) => setFormData({...formData, nom_complet: e.target.value})}
                    className="w-full border border-gray-300 rounded-md shadow-sm px-3 py-2 focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Ex: Jean Dupont"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Email *
                  </label>
                  <input
                    type="email"
                    required
                    value={formData.email}
                    onChange={(e) => setFormData({...formData, email: e.target.value})}
                    className="w-full border border-gray-300 rounded-md shadow-sm px-3 py-2 focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Ex: jean.dupont@exemple.com"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Téléphone
                  </label>
                  <input
                    type="text"
                    value={formData.telephone}
                    onChange={(e) => setFormData({...formData, telephone: e.target.value})}
                    className="w-full border border-gray-300 rounded-md shadow-sm px-3 py-2 focus:ring-blue-500 focus:border-blue-500"
                    placeholder="Ex: +33 1 23 45 67 89"
                  />
                </div>
                <div className="flex items-center">
                  <input
                    type="checkbox"
                    checked={formData.is_active}
                    onChange={(e) => setFormData({...formData, is_active: e.target.checked})}
                    className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                  <label className="ml-2 block text-sm text-gray-900">
                    Partenaire actif
                  </label>
                </div>
              </div>
              
              <div className="flex justify-end space-x-3 pt-4">
                <button
                  type="button"
                  onClick={() => setShowForm(false)}
                  className="bg-gray-300 hover:bg-gray-400 text-gray-800 px-4 py-2 rounded-md text-sm font-medium transition-colors"
                >
                  Annuler
                </button>
                <button
                  type="submit"
                  disabled={submitting}
                  className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-md text-sm font-medium disabled:opacity-50 transition-colors"
                >
                  {submitting ? 'Création...' : 'Créer le partenaire'}
                </button>
              </div>
            </form>
          </div>
        )}

        {/* Liste des partenaires */}
        <div className="bg-white shadow overflow-hidden sm:rounded-md">
          <div className="px-4 py-5 sm:px-6 border-b border-gray-200">
            <h3 className="text-lg leading-6 font-medium text-gray-900">
              📋 Liste des partenaires
            </h3>
            <p className="mt-1 max-w-2xl text-sm text-gray-500">
              {loading ? 'Chargement en cours...' : `${partenaires.length} partenaire(s) dans votre base de données`}
            </p>
          </div>

          {loading ? (
            <div className="px-4 py-12 text-center">
              <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600 mx-auto mb-4"></div>
              <p className="text-gray-500">Chargement des partenaires...</p>
            </div>
          ) : partenaires.length === 0 ? (
            <div className="px-4 py-12 text-center">
              <svg className="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
              <h3 className="mt-2 text-sm font-medium text-gray-900">Aucun partenaire</h3>
              <p className="mt-1 text-sm text-gray-500">
                Commencez par créer votre premier partenaire.
              </p>
              <div className="mt-6">
                <button
                  onClick={() => setShowForm(true)}
                  className="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700"
                >
                  <svg className="-ml-1 mr-2 h-5 w-5" fill="currentColor" viewBox="0 0 20 20">
                    <path fillRule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clipRule="evenodd" />
                  </svg>
                  Nouveau partenaire
                </button>
              </div>
            </div>
          ) : (
            <ul className="divide-y divide-gray-200">
              {partenaires.map((partenaire) => (
                <li key={partenaire.id} className="px-4 py-4 sm:px-6 hover:bg-gray-50">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center min-w-0 flex-1">
                      <div className="flex-shrink-0">
                        <div className={`h-10 w-10 rounded-full flex items-center justify-center ${
                          partenaire.is_active ? 'bg-green-100' : 'bg-red-100'
                        }`}>
                          <span className={`text-lg ${
                            partenaire.is_active ? 'text-green-600' : 'text-red-600'
                          }`}>
                            {partenaire.is_active ? '🤝' : '💤'}
                          </span>
                        </div>
                      </div>
                      <div className="ml-4 min-w-0 flex-1">
                        <div className="flex items-center justify-between">
                          <div>
                            <p className="text-sm font-medium text-gray-900 truncate">
                              {partenaire.nom_complet}
                            </p>
                            <p className="text-sm text-gray-500 truncate">
                              {partenaire.email}
                            </p>
                            {partenaire.telephone && (
                              <p className="text-xs text-gray-400">
                                📞 {partenaire.telephone}
                              </p>
                            )}
                          </div>
                          <div className="flex items-center space-x-2">
                            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                              partenaire.is_active 
                                ? 'bg-green-100 text-green-800' 
                                : 'bg-red-100 text-red-800'
                            }`}>
                              {partenaire.is_active ? 'Actif' : 'Inactif'}
                            </span>
                            <span className="text-xs text-gray-400">
                              {new Date(partenaire.created_at).toLocaleDateString('fr-FR')}
                            </span>
                          </div>
                        </div>
                      </div>
                    </div>
                    
                    <div className="flex items-center space-x-2 ml-4">
                      <button
                        onClick={() => toggleActive(partenaire.id, partenaire.is_active)}
                        className={`px-3 py-1 rounded text-xs font-medium transition-colors ${
                          partenaire.is_active
                            ? 'bg-yellow-100 text-yellow-800 hover:bg-yellow-200'
                            : 'bg-green-100 text-green-800 hover:bg-green-200'
                        }`}
                      >
                        {partenaire.is_active ? 'Désactiver' : 'Activer'}
                      </button>
                      <button
                        onClick={() => deletePartenaire(partenaire.id, partenaire.nom_complet)}
                        className="px-3 py-1 bg-red-100 text-red-800 rounded text-xs font-medium hover:bg-red-200 transition-colors"
                      >
                        Supprimer
                      </button>
                    </div>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  )
}