// ─────────────────────────────────────────────────────────────────────────────
// PreferencesStore — localStorage-backed app preferences
// ─────────────────────────────────────────────────────────────────────────────

import type { AppPreferences } from '../models/CoreTypes'
import { DEFAULT_PREFERENCES } from '../models/CoreTypes'

const KEY = 'panchangam:prefs'

export function loadPreferences(): AppPreferences {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return { ...DEFAULT_PREFERENCES }
    return { ...DEFAULT_PREFERENCES, ...JSON.parse(raw) }
  } catch {
    return { ...DEFAULT_PREFERENCES }
  }
}

export function savePreferences(prefs: AppPreferences): void {
  localStorage.setItem(KEY, JSON.stringify(prefs))
}
