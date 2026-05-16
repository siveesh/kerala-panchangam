// ─────────────────────────────────────────────────────────────────────────────
// useProfiles — React hook for family profile CRUD
// ─────────────────────────────────────────────────────────────────────────────

import { useState, useEffect, useCallback } from 'react'
import * as FamilyStore from '../store/FamilyStore'
import type { PersonProfile } from '../models/FamilyTypes'

export function useProfiles() {
  const [profiles, setProfiles] = useState<PersonProfile[]>([])
  const [isLoading, setIsLoading] = useState(true)

  useEffect(() => {
    FamilyStore.loadProfiles().then(p => {
      setProfiles(p)
      setIsLoading(false)
    })
  }, [])

  const saveProfile = useCallback(async (profile: PersonProfile) => {
    await FamilyStore.saveProfile(profile)
    setProfiles(prev => {
      const idx = prev.findIndex(p => p.id === profile.id)
      return idx >= 0
        ? prev.map(p => p.id === profile.id ? profile : p)
        : [...prev, profile]
    })
  }, [])

  const deleteProfile = useCallback(async (id: string) => {
    await FamilyStore.deleteProfile(id)
    setProfiles(prev => prev.filter(p => p.id !== id))
  }, [])

  const importProfiles = useCallback(async (json: string) => {
    const imported = FamilyStore.importBackupJSON(json)
    await FamilyStore.replaceAllProfiles(imported)
    setProfiles(imported)
  }, [])

  const exportProfiles = useCallback(() => {
    return FamilyStore.exportBackupJSON(profiles)
  }, [profiles])

  return { profiles, isLoading, saveProfile, deleteProfile, importProfiles, exportProfiles }
}
