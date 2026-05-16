// ─────────────────────────────────────────────────────────────────────────────
// AstronomyEngine
// Ported from ApproximateAstronomyEngine.swift (74 lines)
// Provides Sun longitude, Moon longitude, ayanamsa, and solar day.
// ─────────────────────────────────────────────────────────────────────────────

import { toRad, toDeg, normalise, julianDay, julianCenturies, tzOffsetMinutes } from '../utils/math'
import { tropicalGeocentricLongitude } from './PlanetaryCalculator'
import type { GeoLocation } from '../models/CoreTypes'

export interface SolarDay {
  sunrise: Date   // UTC Date
  sunset: Date    // UTC Date
}

// ---------------------------------------------------------------------------
// Ayanamsa (Lahiri / Chitrapaksha)
// IAU reference: 23.1898° at J2000.0; precession 50.290966"/year
// ---------------------------------------------------------------------------
export function lahiriAyanamsa(date: Date): number {
  const jd = julianDay(date)
  const T = julianCenturies(jd)
  const years = T * 100
  return 23.1898 + (50.290966 / 3600) * years
}

// ---------------------------------------------------------------------------
// Tropical Sun longitude at a given UTC Date
// ---------------------------------------------------------------------------
export function tropicalSunLongitude(date: Date): number {
  return tropicalGeocentricLongitude('sun', julianDay(date))
}

// ---------------------------------------------------------------------------
// Tropical Moon longitude at a given UTC Date
// ---------------------------------------------------------------------------
export function tropicalMoonLongitude(date: Date): number {
  return tropicalGeocentricLongitude('moon', julianDay(date))
}

// ---------------------------------------------------------------------------
// Sidereal longitudes (subtract ayanamsa)
// ---------------------------------------------------------------------------
export function siderealSunLongitude(date: Date): number {
  return normalise(tropicalSunLongitude(date) - lahiriAyanamsa(date))
}

export function siderealMoonLongitude(date: Date): number {
  return normalise(tropicalMoonLongitude(date) - lahiriAyanamsa(date))
}

// ---------------------------------------------------------------------------
// Sunrise / Sunset
// USNO algorithm via hour angle of the Sun.
// Returns UTC Dates for sunrise and sunset on the calendar date containing
// the given UTC Date, at the given location.
// ---------------------------------------------------------------------------
export function solarDay(date: Date, location: GeoLocation): SolarDay {
  const jd = julianDay(date)
  const lat = toRad(location.latitude)
  const lon = location.longitude  // degrees

  const T  = julianCenturies(jd)
  // Mean longitude and mean anomaly of the Sun
  const L0 = normalise(280.46646 + 36000.76983 * T)
  const M  = toRad(normalise(357.52911 + 35999.05029 * T))
  // Equation of centre
  const C = (1.914602 - 0.004817*T) * Math.sin(M)
           + 0.019993 * Math.sin(2*M)
           + 0.000289 * Math.sin(3*M)
  const sunLon = toRad(normalise(L0 + C))

  // Obliquity of ecliptic (approximate)
  const eps = toRad(23.439 - 0.0000004 * T * 36525)

  // Sun declination
  const sinDec = Math.sin(eps) * Math.sin(sunLon)
  const dec = Math.asin(sinDec)

  // Hour angle for standard sunrise (solar depression = -0.833°)
  const cosH = (Math.cos(toRad(-0.8333)) - Math.sin(lat) * sinDec)
             / (Math.cos(lat) * Math.cos(dec))
  // Clamp to avoid NaN at extreme latitudes
  const cosHClamped = Math.max(-1, Math.min(1, cosH))
  const H = toDeg(Math.acos(cosHClamped))  // degrees

  // Equation of time (minutes) — Meeus simplified
  const f = 279.575 + 0.9856 * (jd - 2451545)
  const fr = toRad(f)
  const EoT = -104 * Math.sin(fr) + 596 * Math.cos(fr)
            - 4 * Math.sin(2 * fr) - 12.79 * Math.cos(2 * fr) - 429 * Math.sin(fr - Math.PI/6)
  const EoTmin = EoT / 60

  // Local apparent noon offset from UTC noon
  const noonOffsetMin = -lon * 4 + EoTmin  // minutes from UTC noon

  // UTC times (minutes past midnight)
  const noonUTC = 720 + noonOffsetMin       // 720 = 12 * 60
  const sunriseUTC = noonUTC - H * 4
  const sunsetUTC  = noonUTC + H * 4

  // Build Date objects: use the calendar-date portion in the location's TZ
  const tzOffset = tzOffsetMinutes(date, location.timeZoneId)
  // "Today" in local time — find the UTC start of the local calendar day
  const localDayStart = new Date(date.getTime() - (tzOffset - Math.floor(tzOffset / (24*60)) * (24*60)) * 60_000)
  const startOfLocalDay = new Date(localDayStart)
  startOfLocalDay.setUTCHours(0, 0, 0, 0)
  // Adjust to local midnight in UTC
  const localMidnightUTC = new Date(startOfLocalDay.getTime() - tzOffset * 60_000)

  const sunrise = new Date(localMidnightUTC.getTime() + sunriseUTC * 60_000)
  const sunset  = new Date(localMidnightUTC.getTime() + sunsetUTC  * 60_000)

  return { sunrise, sunset }
}
