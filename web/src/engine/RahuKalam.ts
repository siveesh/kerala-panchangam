// ─────────────────────────────────────────────────────────────────────────────
// RahuKalam, Yamagandam, Gulika Kalam
// Ported from RahuPeriodCalculator.swift (38 lines)
// ─────────────────────────────────────────────────────────────────────────────

import type { TimePeriod } from '../models/PanchangamDay'
import { localWeekday } from '../utils/math'

// Traditional Hindu weekday → 1-indexed daytime part (1 = earliest, 8 = latest)
// Weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
// Values confirmed by traditional Kerala Panchangam sources:
const RAHU_PART:       Record<number, number> = { 1:7, 2:1, 3:6, 4:5, 5:4, 6:3, 7:2 }
const YAMAGANDAM_PART: Record<number, number> = { 1:4, 2:3, 3:2, 4:1, 5:7, 6:6, 7:5 }
const GULIKA_PART:     Record<number, number> = { 1:6, 2:5, 3:4, 4:3, 5:2, 6:1, 7:7 }

export interface RahuPeriods {
  rahuKalam: TimePeriod
  yamagandam: TimePeriod
  gulikaKalam: TimePeriod
}

/**
 * Compute Rahu Kalam, Yamagandam, and Gulika Kalam for a given day.
 * @param date    Any UTC Date on the day of interest
 * @param sunrise UTC Date of sunrise
 * @param sunset  UTC Date of sunset
 * @param tzId    IANA timezone string (used to determine weekday)
 */
export function rahuPeriods(date: Date, sunrise: Date, sunset: Date, tzId: string): RahuPeriods {
  const weekday = localWeekday(date, tzId)  // 1=Sun..7=Sat
  const dayMs = sunset.getTime() - sunrise.getTime()
  const partMs = dayMs / 8

  function period(part: number): TimePeriod {
    const start = new Date(sunrise.getTime() + (part - 1) * partMs)
    const end   = new Date(sunrise.getTime() + part * partMs)
    return { start, end }
  }

  return {
    rahuKalam:   period(RAHU_PART[weekday]),
    yamagandam:  period(YAMAGANDAM_PART[weekday]),
    gulikaKalam: period(GULIKA_PART[weekday]),
  }
}
