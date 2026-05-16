// ─────────────────────────────────────────────────────────────────────────────
// PanchangamDay — the primary output of the calculation engine for one day
// ─────────────────────────────────────────────────────────────────────────────

import type { NakshatraId, MalayalamMonthId, TithiId } from './MalayalamCalendar'
import type { GeoLocation } from './CoreTypes'

export interface TimePeriod {
  start: Date
  end: Date
}

export interface NakshatraPeriod {
  nakshatra: NakshatraId
  start: Date
  end: Date
  durationHours: number
}

export interface PanchangamDay {
  date: Date                       // Gregorian date (local midnight in location TZ)
  location: GeoLocation
  sunrise: Date
  sunset: Date
  mainNakshatra: NakshatraId       // Nakshatra per chosen CalculationMode
  nakshatraPeriods: NakshatraPeriod[]
  tithi: TithiId
  malayalamMonth: MalayalamMonthId
  malayalamDay: number             // 1–31
  kollavarshamYear: number         // e.g. 1201
  rahuKalam: TimePeriod
  yamagandam: TimePeriod
  gulikaKalam: TimePeriod
}
