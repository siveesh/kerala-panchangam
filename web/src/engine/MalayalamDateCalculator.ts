// ─────────────────────────────────────────────────────────────────────────────
// MalayalamDateCalculator
// Ported from MalayalamDateCalculator.swift (36 lines)
// ─────────────────────────────────────────────────────────────────────────────

import type { MalayalamMonthId } from '../models/MalayalamCalendar'

// Sidereal mean solar motion (degrees/day) — sidereal year basis
const SIDEREAL_SOLAR_MOTION = 0.98560910

export interface MalayalamDate {
  month: MalayalamMonthId
  day: number
  kollavarshamYear: number
}

/**
 * Compute the Malayalam date from the sidereal Sun longitude.
 * @param siderealSunLon  Sidereal Sun longitude in degrees [0, 360)
 * @param gregorianYear   The Gregorian year of this date (for KE year offset)
 * @param gregorianMonth  1-based Gregorian month
 */
export function malayalamDate(
  siderealSunLon: number,
  gregorianYear: number,
  gregorianMonth: number,
): MalayalamDate {
  // Malayalam month = sidereal zodiac sign (Leo = Chingam = 0)
  // Leo starts at 120° in the tropical zodiac, but since we use sidereal Sun,
  // we map: Chingam (Leo) = 120°, Kanni (Virgo) = 150°, ..., Karkidakam (Cancer) = 90°
  // The mapping is: month = floor(siderealSunLon / 30), then shift by Leo offset.
  // Tropical sign 0 = Aries; Malayalam month 0 = Chingam (Leo, sign 4).
  // sidereal Aries start = 0°. Leo = 120°.
  const signIndex = Math.floor(siderealSunLon / 30)  // 0=Aries .. 11=Pisces
  // Map: Aries(0) -> Medam(8), Taurus(1)->Edavam(9), ..., Leo(4)->Chingam(0)
  const SIGN_TO_MONTH: MalayalamMonthId[] = [8, 9, 10, 11, 0, 1, 2, 3, 4, 5, 6, 7]
  const month = SIGN_TO_MONTH[signIndex]

  // Day within the month = degrees into the current sign / mean daily motion
  const degreesIntoSign = siderealSunLon - signIndex * 30
  const day = Math.max(1, Math.min(31, Math.floor(degreesIntoSign / SIDEREAL_SOLAR_MOTION) + 1))

  // Kollavarsham (Kerala Era) year:
  // If Malayalam month is Chingam through Karkidakam (Leo–Cancer, i.e. Aug–Jul), KE = Gregorian - 825
  // Months after Chingam (≥1) that occur Aug-Dec use gregorianYear - 824
  // Simple rule used in the Swift app: months 0-7 (Chingam-Meenam) → gregorianYear - 824
  //   months 8-11 (Medam-Karkidakam) → gregorianYear - 825
  // Note: cross-check this with the original Swift logic.
  // Swift: Chingam-Dhanu (0-4) → year-824; Makaram-Karkidakam (5-11) → year-825
  const kollavarshamYear = month <= 4 ? gregorianYear - 824 : gregorianYear - 825

  return { month, day, kollavarshamYear }
}
