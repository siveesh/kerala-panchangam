// ─────────────────────────────────────────────────────────────────────────────
// NakshatraOccurrenceAnalyzer
// Ported from NakshatraOccurrenceAnalyzer.swift (198 lines)
// Groups nakshatra occurrences within a month and applies duplicate policies.
// ─────────────────────────────────────────────────────────────────────────────

import type { PanchangamDay } from '../models/PanchangamDay'
import type { NakshatraId, MalayalamMonthId } from '../models/MalayalamCalendar'
import type { DuplicateNakshatraPolicy } from '../models/FamilyTypes'

export interface NakshatraOccurrence {
  days: PanchangamDay[]
  durationHours: number
}

export interface NakshatraAnalysis {
  occurrences: NakshatraOccurrence[]
  recommendedDays: PanchangamDay[]
}

/**
 * Analyse occurrences of a given nakshatra within the birth/death month.
 * @param nakshatra  The nakshatra to look for
 * @param month      The Malayalam month to filter on
 * @param days       All PanchangamDay objects for the relevant period
 * @param policy     Duplicate handling policy
 * @param durationThresholdHours  Threshold for 'preferSecondUnlessShort' (default 6h)
 */
export function analyze(
  nakshatra: NakshatraId,
  month: MalayalamMonthId,
  days: PanchangamDay[],
  policy: DuplicateNakshatraPolicy,
  durationThresholdHours = 6,
): NakshatraAnalysis {
  // Filter days with matching nakshatra and month
  const matching = days
    .filter(d => d.mainNakshatra === nakshatra && d.malayalamMonth === month)
    .sort((a, b) => a.date.getTime() - b.date.getTime())

  if (matching.length === 0) {
    return { occurrences: [], recommendedDays: [] }
  }

  // Split into consecutive runs (a nakshatra can span 2 consecutive days)
  const runs = splitConsecutiveRuns(matching)
  const occurrences = runs.map(runDays => ({
    days: runDays,
    durationHours: totalNakshatraDuration(runDays),
  }))

  const recommendedDays = applyPolicy(occurrences, policy, durationThresholdHours)
  return { occurrences, recommendedDays }
}

/**
 * Split a sorted array of days into groups of consecutive days.
 */
export function splitConsecutiveRuns(days: PanchangamDay[]): PanchangamDay[][] {
  if (days.length === 0) return []
  const runs: PanchangamDay[][] = []
  let current = [days[0]]
  for (let i = 1; i < days.length; i++) {
    const prev = days[i - 1].date.getTime()
    const curr = days[i].date.getTime()
    const diffDays = Math.round((curr - prev) / 86_400_000)
    if (diffDays <= 1) {
      current.push(days[i])
    } else {
      runs.push(current)
      current = [days[i]]
    }
  }
  runs.push(current)
  return runs
}

/**
 * Compute total nakshatra coverage hours for a run of days.
 * Uses the nakshatra period data from each day.
 */
function totalNakshatraDuration(days: PanchangamDay[]): number {
  return days.reduce((sum, d) => {
    const nk = d.mainNakshatra
    const periods = d.nakshatraPeriods.filter(p => p.nakshatra === nk)
    return sum + periods.reduce((s, p) => s + p.durationHours, 0)
  }, 0)
}

function applyPolicy(
  occurrences: NakshatraOccurrence[],
  policy: DuplicateNakshatraPolicy,
  threshold: number,
): PanchangamDay[] {
  if (occurrences.length === 0) return []
  if (occurrences.length === 1) return [occurrences[0].days[0]]

  switch (policy) {
    case 'alwaysFirst':
      return [occurrences[0].days[0]]

    case 'alwaysSecond':
      return [occurrences[1].days[0]]

    case 'longestDuration': {
      const longest = occurrences.reduce((a, b) => a.durationHours > b.durationHours ? a : b)
      return [longest.days[0]]
    }

    case 'preferSecondUnlessShort': {
      const second = occurrences[1]
      if (second.durationHours < threshold) {
        return [occurrences[0].days[0]]
      }
      return [second.days[0]]
    }
  }
}

// ---------------------------------------------------------------------------
// Consecutive month instances (for cross-year months like Dhanu/Makaram)
// Ported from FamilyEventGenerator.consecutiveMonthInstances
// ---------------------------------------------------------------------------
export function consecutiveMonthInstances(
  month: MalayalamMonthId,
  days: PanchangamDay[],
): PanchangamDay[][] {
  const filtered = days
    .filter(d => d.malayalamMonth === month)
    .sort((a, b) => a.date.getTime() - b.date.getTime())

  if (filtered.length === 0) return []

  const instances: PanchangamDay[][] = []
  let current = [filtered[0]]

  for (let i = 1; i < filtered.length; i++) {
    const prev = filtered[i - 1].date.getTime()
    const curr = filtered[i].date.getTime()
    const diffDays = Math.round((curr - prev) / 86_400_000)
    if (diffDays <= 1) {
      current.push(filtered[i])
    } else {
      instances.push(current)
      current = [filtered[i]]
    }
  }
  instances.push(current)
  return instances
}
