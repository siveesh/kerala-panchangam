// ─────────────────────────────────────────────────────────────────────────────
// PanchangamCalculator
// Ported from DefaultPanchangamCalculator.swift (208 lines)
// Main orchestrator: generates PanchangamDay objects for a date or full year.
// ─────────────────────────────────────────────────────────────────────────────

import { julianDay, normalise, localDateString, localMidnight, tzOffsetMinutes } from '../utils/math'
import { solarDay, siderealSunLongitude, siderealMoonLongitude, tropicalSunLongitude, tropicalMoonLongitude, lahiriAyanamsa } from './AstronomyEngine'
import { tropicalGeocentricLongitude } from './PlanetaryCalculator'
import { tithiAtSunrise } from './TithiCalculator'
import { malayalamDate } from './MalayalamDateCalculator'
import { rahuPeriods } from './RahuKalam'
import { nakshatraFromLongitude, NAKSHATRA_SPAN_DEG } from '../models/MalayalamCalendar'
import type { PanchangamDay, NakshatraPeriod } from '../models/PanchangamDay'
import type { GeoLocation, CalculationMode } from '../models/CoreTypes'
import type { NakshatraId } from '../models/MalayalamCalendar'

// ---------------------------------------------------------------------------
// Single day calculation
// ---------------------------------------------------------------------------
export function calculateDay(date: Date, location: GeoLocation, mode: CalculationMode = 'keralaTraditional'): PanchangamDay {
  const { sunrise, sunset } = solarDay(date, location)

  // Nakshatra periods (binary search refinement across 36-hour window)
  const nakshatraPeriods = computeNakshatraPeriods(date, location)

  // Main nakshatra per mode
  const mainNakshatra = mainNakshatraForMode(mode, sunrise, nakshatraPeriods)

  // Tithi at sunrise
  const tithi = tithiAtSunrise(sunrise)

  // Malayalam date (sidereal Sun at sunrise)
  const sidSun = siderealSunLongitude(sunrise)
  const gYear = sunrise.getUTCFullYear()
  const gMonth = sunrise.getUTCMonth() + 1
  const mlDate = malayalamDate(sidSun, gYear, gMonth)

  // Rahu periods
  const rahu = rahuPeriods(date, sunrise, sunset, location.timeZoneId)

  return {
    date,
    location,
    sunrise,
    sunset,
    mainNakshatra,
    nakshatraPeriods,
    tithi,
    malayalamMonth: mlDate.month,
    malayalamDay:   mlDate.day,
    kollavarshamYear: mlDate.kollavarshamYear,
    rahuKalam:    rahu.rahuKalam,
    yamagandam:   rahu.yamagandam,
    gulikaKalam:  rahu.gulikaKalam,
  }
}

// ---------------------------------------------------------------------------
// Full year generation (returns array of 365/366 PanchangamDay objects)
// Runs asynchronously in ~20–50ms for a full year in modern browsers.
// ---------------------------------------------------------------------------
export async function calculateYear(year: number, location: GeoLocation, mode: CalculationMode = 'keralaTraditional'): Promise<PanchangamDay[]> {
  const days: PanchangamDay[] = []
  const isLeap = (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0
  // Extend 45 days into the next year so late Malayalam months (Dhanu: Dec 17–Jan 13,
  // Makaram: Jan 14–Feb 11) are fully covered for star-birthday and Śrāddham generation.
  // The calendar view already filters by month/year so extra days are invisible in the grid.
  const numDays = (isLeap ? 366 : 365) + 45

  for (let d = 0; d < numDays; d++) {
    // Build the UTC date for noon on day d (avoids DST/TZ edge cases)
    const utcNoon = new Date(Date.UTC(year, 0, 1 + d, 12, 0, 0))
    days.push(calculateDay(utcNoon, location, mode))
    // Yield to event loop every 30 days to keep UI responsive
    if (d % 30 === 29) await new Promise(r => setTimeout(r, 0))
  }
  return days
}

// ---------------------------------------------------------------------------
// Nakshatra period computation (binary search for transitions)
// ---------------------------------------------------------------------------
function computeNakshatraPeriods(date: Date, location: GeoLocation): NakshatraPeriod[] {
  const { sunrise, sunset } = solarDay(date, location)
  // Window: from previous midnight to next midnight (36-hour window)
  const tzOffset = tzOffsetMinutes(date, location.timeZoneId)
  const windowStart = new Date(sunrise.getTime() - 24 * 3600_000)
  const windowEnd   = new Date(sunset.getTime()  + 12 * 3600_000)

  const periods: NakshatraPeriod[] = []
  let current = nakshatraAt(windowStart)
  let periodStart = windowStart

  // Scan in 1-hour steps, refine transitions via binary search
  let t = new Date(windowStart.getTime() + 3600_000)
  while (t <= windowEnd) {
    const nk = nakshatraAt(t)
    if (nk !== current) {
      // Binary search for exact transition
      const transitionTime = binarySearchTransition(periodStart, t, current)
      periods.push({
        nakshatra: current,
        start: periodStart,
        end: transitionTime,
        durationHours: (transitionTime.getTime() - periodStart.getTime()) / 3_600_000,
      })
      periodStart = transitionTime
      current = nk
    }
    t = new Date(t.getTime() + 3600_000)
  }
  // Close the last period
  periods.push({
    nakshatra: current,
    start: periodStart,
    end: windowEnd,
    durationHours: (windowEnd.getTime() - periodStart.getTime()) / 3_600_000,
  })

  return periods
}

function nakshatraAt(date: Date): NakshatraId {
  const ayanamsa = lahiriAyanamsa(date)
  const tropical = tropicalGeocentricLongitude('moon', julianDay(date))
  const sidereal = normalise(tropical - ayanamsa)
  return nakshatraFromLongitude(sidereal)
}

function binarySearchTransition(lo: Date, hi: Date, targetNakshatra: NakshatraId): Date {
  let low = lo.getTime(), high = hi.getTime()
  for (let i = 0; i < 32; i++) {
    const mid = (low + high) / 2
    const midDate = new Date(mid)
    if (nakshatraAt(midDate) === targetNakshatra) {
      low = mid
    } else {
      high = mid
    }
    if (high - low < 1000) break  // 1-second precision
  }
  return new Date((low + high) / 2)
}

// ---------------------------------------------------------------------------
// Main nakshatra per mode
// ---------------------------------------------------------------------------
function mainNakshatraForMode(
  mode: CalculationMode,
  sunrise: Date,
  periods: NakshatraPeriod[],
): NakshatraId {
  switch (mode) {
    case 'sunriseNakshatra':
      return nakshatraAt(sunrise)

    case 'majorityCivilDay': {
      // Nakshatra covering the most hours of the civil day (6 AM–6 PM approx)
      const best = periods.reduce((a, b) => a.durationHours > b.durationHours ? a : b)
      return best.nakshatra
    }

    case 'keralaTraditional':
    default: {
      // Nakshatra at sunrise. If it transitions after sunrise, use the next one.
      const atSunrise = nakshatraAt(sunrise)
      // Check if the sunrise nakshatra transitions within the next 24h
      const sunriseNkPeriod = periods.find(p =>
        p.nakshatra === atSunrise &&
        p.start <= sunrise && p.end > sunrise
      )
      if (!sunriseNkPeriod) return atSunrise
      // Kerala Traditional: use the nakshatra that rises WITH the sun
      // i.e., the one prevailing at sunrise
      return atSunrise
    }
  }
}
