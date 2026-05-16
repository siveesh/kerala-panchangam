// ─────────────────────────────────────────────────────────────────────────────
// TithiCalculator
// Ported from TithiCalculator.swift (9 lines)
// ─────────────────────────────────────────────────────────────────────────────

import { normalise, julianDay } from '../utils/math'
import { tithiFromElongation } from '../models/MalayalamCalendar'
import { tropicalSunLongitude, tropicalMoonLongitude, lahiriAyanamsa } from './AstronomyEngine'
import type { TithiId } from '../models/MalayalamCalendar'

export function tithiAtDate(date: Date): TithiId {
  const sun  = tropicalSunLongitude(date)
  const moon = tropicalMoonLongitude(date)
  const elongation = normalise(moon - sun)
  return tithiFromElongation(elongation)
}

/** Tithi at sunrise of a given day */
export function tithiAtSunrise(sunrise: Date): TithiId {
  return tithiAtDate(sunrise)
}
