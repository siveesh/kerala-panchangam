// ─────────────────────────────────────────────────────────────────────────────
// usePanchangam — React hook for generating and caching panchangam data
// ─────────────────────────────────────────────────────────────────────────────

import { useState, useEffect, useCallback, useRef } from 'react'
import { calculateYear } from '../engine/PanchangamCalculator'
import type { PanchangamDay } from '../models/PanchangamDay'
import type { AppPreferences } from '../models/CoreTypes'

export interface PanchangamState {
  days: PanchangamDay[]
  isLoading: boolean
  error: string | null
  year: number
  loadYear: (y: number) => void
}

export function usePanchangam(prefs: AppPreferences): PanchangamState {
  const [year, setYear] = useState(() => new Date().getFullYear())
  const [days, setDays] = useState<PanchangamDay[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Track in-flight generation to cancel stale requests
  const genIdRef = useRef(0)

  useEffect(() => {
    const id = ++genIdRef.current
    setIsLoading(true)
    setError(null)

    calculateYear(year, prefs.location, prefs.calculationMode)
      .then(result => {
        if (id !== genIdRef.current) return  // stale
        setDays(result)
        setIsLoading(false)
      })
      .catch(err => {
        if (id !== genIdRef.current) return
        setError(String(err))
        setIsLoading(false)
      })
  }, [year, prefs.location.latitude, prefs.location.longitude, prefs.location.timeZoneId, prefs.calculationMode])

  const loadYear = useCallback((y: number) => setYear(y), [])

  return { days, isLoading, error, year, loadYear }
}
