// ─────────────────────────────────────────────────────────────────────────────
// ShraddhamDateFinder
// Ported from ShraddhamDateFinder.swift (153 lines)
// ─────────────────────────────────────────────────────────────────────────────

import { analyze, consecutiveMonthInstances } from '../engine/NakshatraAnalyzer'
import type { PanchangamDay } from '../models/PanchangamDay'
import type { PersonProfile, ShraddhamDate, ShraddhamObservanceMode } from '../models/FamilyTypes'
import type { MalayalamMonthId, TithiId } from '../models/MalayalamCalendar'
import { TITHIS } from '../models/MalayalamCalendar'

function gregDateKey(d: Date): string {
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth()+1).padStart(2,'0')}-${String(d.getUTCDate()).padStart(2,'0')}`
}

export function shraddhamDates(
  profile: PersonProfile,
  days: PanchangamDay[],
  mode: ShraddhamObservanceMode = 'nakshatraOnly',
): ShraddhamDate[] {
  if (!profile.deathDetails) return []
  const death = profile.deathDetails

  switch (mode) {
    case 'nakshatraOnly':
      return nakshatraDates(profile, death, days)

    case 'nakshatraPreferred': {
      const r = nakshatraDates(profile, death, days)
      return r.length > 0 ? r : tithiDates(profile, death, days)
    }

    case 'tithiPreferred': {
      const r = tithiDates(profile, death, days)
      return r.length > 0 ? r : nakshatraDates(profile, death, days)
    }

    case 'tithiAndNakshatra': {
      const tithi    = tithiDates(profile, death, days)
      const naksh    = nakshatraDates(profile, death, days)
      const seen     = new Set<string>()
      return [...tithi, ...naksh].filter(sd => {
        const k = gregDateKey(sd.gregorianDate)
        return seen.has(k) ? false : (seen.add(k), true)
      })
    }
  }
}

// ---------------------------------------------------------------------------
// Nakshatra-based (Kerala traditional — FIRST occurrence)
// ---------------------------------------------------------------------------
function nakshatraDates(
  profile: PersonProfile,
  death: NonNullable<PersonProfile['deathDetails']>,
  days: PanchangamDay[],
): ShraddhamDate[] {
  if (death.deathNakshatra === undefined || death.deathMalayalamMonth === undefined) return []
  const nakshatra = death.deathNakshatra
  const month = death.deathMalayalamMonth

  const instances = consecutiveMonthInstances(month, days)
  const results: ShraddhamDate[] = []

  for (const instanceDays of instances) {
    const { recommendedDays } = analyze(nakshatra, month, instanceDays, 'alwaysFirst')
    if (recommendedDays.length === 0) continue
    const day = recommendedDays[0]
    const tithiInfo = TITHIS[day.tithi]
    results.push({
      id: crypto.randomUUID(),
      personId: profile.id,
      personName: profile.nickname.trim() !== '' ? profile.nickname : profile.fullName,
      gregorianDate: day.date,
      tithi: day.tithi,
      paksha: tithiInfo.paksha,
      malayalamDateLabel: `${monthLabel(day.malayalamMonth)} ${day.malayalamDay} · ${day.kollavarshamYear}`,
      selectionRuleDescription: `Nakshatra: ${nakshatraLabel(nakshatra)} in ${monthLabel(month)}`,
    })
  }
  return results
}

// ---------------------------------------------------------------------------
// Tithi-based
// ---------------------------------------------------------------------------
function tithiDates(
  profile: PersonProfile,
  death: NonNullable<PersonProfile['deathDetails']>,
  days: PanchangamDay[],
): ShraddhamDate[] {
  if (death.deathTithi === undefined) return []
  const deathTithi = death.deathTithi

  // Group by Kollavarsham year
  const byYear = new Map<number, PanchangamDay[]>()
  for (const d of days) {
    const yr = d.kollavarshamYear
    if (!byYear.has(yr)) byYear.set(yr, [])
    byYear.get(yr)!.push(d)
  }

  const results: ShraddhamDate[] = []
  const sortedYears = [...byYear.keys()].sort((a,b) => a - b)

  for (const yr of sortedYears) {
    const candidates = byYear.get(yr)!.filter(d => d.tithi === deathTithi)
    if (candidates.length === 0) continue
    const selected = candidates[0]  // sunrise-tithi rule: first occurrence
    const tithiInfo = TITHIS[deathTithi]
    results.push({
      id: crypto.randomUUID(),
      personId: profile.id,
      personName: profile.nickname.trim() !== '' ? profile.nickname : profile.fullName,
      gregorianDate: selected.date,
      tithi: deathTithi,
      paksha: tithiInfo.paksha,
      malayalamDateLabel: `${monthLabel(selected.malayalamMonth)} ${selected.malayalamDay} · ${selected.kollavarshamYear}`,
      selectionRuleDescription: `Tithi: ${tithiInfo.paksha === 'shukla' ? 'S' : 'K'} ${tithiInfo.english}`,
    })
  }
  return results
}

// ---------------------------------------------------------------------------
// Label helpers (avoid importing heavy enum tables here)
// ---------------------------------------------------------------------------
import { NAKSHATRAS, MALAYALAM_MONTHS } from '../models/MalayalamCalendar'
import type { NakshatraId } from '../models/MalayalamCalendar'

function nakshatraLabel(id: NakshatraId): string { return NAKSHATRAS[id].english }
function monthLabel(id: MalayalamMonthId): string { return MALAYALAM_MONTHS[id].english }
