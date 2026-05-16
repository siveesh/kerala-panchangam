// ─────────────────────────────────────────────────────────────────────────────
// PlanetaryCalculator
// Ported from PlanetaryCalculator.swift (317 lines)
// Provides tropical geocentric longitudes for Sun, Moon, and 5 planets.
// ─────────────────────────────────────────────────────────────────────────────

import { toRad, toDeg, normalise, julianDay, julianCenturies, solveKepler } from '../utils/math'

export type PlanetBody = 'sun' | 'moon' | 'mars' | 'mercury' | 'jupiter' | 'venus' | 'saturn' | 'rahu' | 'ketu'

// ---------------------------------------------------------------------------
// Keplerian orbital elements (J2000.0 epoch, per Meeus Table 33.a)
// ---------------------------------------------------------------------------
interface KeplerElements {
  L0: number; L1: number   // mean longitude  (deg, deg/Julian century)
  a0: number               // semi-major axis (AU)
  e0: number; e1: number   // eccentricity
  i0: number; i1: number   // inclination (deg)
  O0: number; O1: number   // longitude of ascending node (deg)
  P0: number; P1: number   // longitude of perihelion (deg)
}

const ELEMENTS: Partial<Record<PlanetBody, KeplerElements>> = {
  mercury: { L0:252.250906, L1:149472.6746358, a0:0.387098310, e0:0.20563175, e1:0.000020407, i0:7.004986, i1:-0.0059516, O0:48.330893, O1:-0.1254229, P0:77.456119, P1:0.1588643 },
  venus:   { L0:181.979801, L1: 58517.8156760, a0:0.723329820, e0:0.00677192, e1:-0.000047766,i0:3.394662, i1:-0.0008568, O0:76.679920, O1:-0.2780080, P0:131.563703,P1:0.0048746 },
  mars:    { L0:355.433000, L1: 19140.2993313, a0:1.523679342, e0:0.09340065, e1:0.000090484, i0:1.849726, i1:-0.0006011, O0:49.558093, O1:-0.2950250, P0:336.060234,P1:0.4439016 },
  jupiter: { L0: 34.351519, L1:  3034.9056606, a0:5.202603191, e0:0.04849793, e1:0.000163225, i0:1.303267, i1:-0.0054965, O0:100.464407,O1:0.1020042, P0:14.331207, P1:0.2155209 },
  saturn:  { L0: 50.077444, L1:  1222.1138488, a0:9.554909192, e0:0.05550825, e1:-0.000346641,i0:2.488879, i1:-0.0037362, O0:113.665503,O1:-0.2566722,P0:93.057237, P1:0.5665415 },
}

// ---------------------------------------------------------------------------
// 30-term Moon longitude series (Meeus Ch.47, top 30 terms by amplitude)
// Each entry: [l, l', F, D, Ω,  Σl (0.001″),  Σr (0.001 km)]
// We only use Σl for longitude.
// ---------------------------------------------------------------------------
const MOON_TERMS: [number,number,number,number,number,number][] = [
  [ 0, 0, 0, 1, 0,  6288774],
  [ 2, 0, 0,-1, 0,  1274027],
  [ 2, 0, 0, 0, 0,   658314],
  [ 0, 0, 0, 2, 0,   213618],
  [ 0, 1, 0, 0, 0,  -185116],
  [ 0, 0, 2, 0, 0,  -114332],
  [ 2, 0,-2, 0, 0,    58793],
  [ 2,-1, 0,-1, 0,    57066],
  [ 2, 0, 2,-1, 0,    53322],
  [ 2,-1, 0, 0, 0,    45758],
  [ 0, 1, 0,-1, 0,   -40923],
  [ 1, 0, 0, 0, 0,   -34720],
  [ 0, 1, 0, 1, 0,   -30383],
  [ 2, 0, 0,-2, 0,    15327],
  [ 0, 0, 2, 1, 0,   -12528],
  [ 0, 0, 2,-1, 0,    10980],
  [ 4, 0, 0,-1, 0,    10675],
  [ 0, 0, 0, 3, 0,    10034],
  [ 4, 0, 0,-2, 0,     8548],
  [ 3,-1, 0, 0, 0,    -7888],
  [ 2, 1, 0,-1, 0,     7212],
  [ 1, 0, 0,-2, 0,    -5966],
  [ 2, 1, 0, 0, 0,     5565],
  [ 0, 0, 4,-1, 0,     5307],
  [ 2, 0, 2, 0, 0,    -4988],
  [ 2,-1, 2,-1, 0,     4296],
  [ 2, 0,-2, 1, 0,    -3516],
  [ 0, 1,-2,-1, 0,     3136],
  [ 2, 0, 4,-2, 0,    -3068],
  [ 2, 0, 4,-1, 0,     2768],
]

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * Tropical geocentric longitude of a body for a given Julian Day.
 * Returns degrees [0, 360).
 */
export function tropicalGeocentricLongitude(body: PlanetBody, jd: number): number {
  switch (body) {
    case 'sun':    return sunGeocentricLongitude(jd)
    case 'moon':   return moonLongitude(jd)
    case 'rahu':   return rahuLongitude(jd)
    case 'ketu':   return normalise(rahuLongitude(jd) + 180)
    default:       return keplerianGeocentricLongitude(body, jd)
  }
}

/**
 * True if the body is retrograde at the given JD (longitude decreasing).
 */
export function isRetrograde(body: PlanetBody, jd: number): boolean {
  if (body === 'sun' || body === 'moon') return false
  const step = 0.5  // 12-hour check
  const L1 = tropicalGeocentricLongitude(body, jd - step)
  const L2 = tropicalGeocentricLongitude(body, jd + step)
  // Handle 360→0 wrap-around
  let delta = L2 - L1
  if (delta > 180) delta -= 360
  if (delta < -180) delta += 360
  return delta < 0
}

// ---------------------------------------------------------------------------
// Sun
// ---------------------------------------------------------------------------
function sunGeocentricLongitude(jd: number): number {
  const T = julianCenturies(jd)
  // Geometric mean longitude of the Sun
  const L0 = normalise(280.46646 + 36000.76983 * T + 0.0003032 * T * T)
  // Mean anomaly of the Sun
  const M = toRad(normalise(357.52911 + 35999.05029 * T - 0.0001537 * T * T))
  // Equation of centre
  const C = (1.914602 - 0.004817 * T - 0.000014 * T * T) * Math.sin(M)
           + (0.019993 - 0.000101 * T) * Math.sin(2 * M)
           + 0.000289 * Math.sin(3 * M)
  // Sun's true longitude
  const sunLon = L0 + C
  // Apparent longitude (aberration correction)
  const omega = toRad(125.04 - 1934.136 * T)
  const apparent = sunLon - 0.00569 - 0.00478 * Math.sin(omega)
  return normalise(apparent)
}

// ---------------------------------------------------------------------------
// Moon (Meeus Ch.47, 30-term series, ±0.05° accuracy)
// ---------------------------------------------------------------------------
function moonLongitude(jd: number): number {
  const T  = julianCenturies(jd)
  const T2 = T * T, T3 = T2 * T, T4 = T3 * T

  // Fundamental arguments (degrees)
  const Lp = normalise(218.3164477 + 481267.88123421*T - 0.0015786*T2 + T3/538841 - T4/65194000)
  const D  = normalise(297.8501921 + 445267.1114034*T  - 0.0018819*T2 + T3/545868 - T4/113065000)
  const M  = normalise(357.5291092 + 35999.0502909*T   - 0.0001536*T2 + T3/24490000)
  const Mp = normalise(134.9633964 + 477198.8675055*T  + 0.0087414*T2 + T3/69699 - T4/14712000)
  const F  = normalise( 93.2720950 + 483202.0175233*T  - 0.0036539*T2 - T3/3526000 + T4/863310000)
  const Om = normalise(125.0445479 - 1934.1362608*T + 0.0020754*T2 + T3/467441 - T4/60616000)

  const Lr = toRad(Lp), Dr = toRad(D), Mr = toRad(M), Mpr = toRad(Mp), Fr = toRad(F), Or = toRad(Om)

  // E correction for Sun's eccentricity
  const E = 1 - 0.002516*T - 0.0000074*T2

  let sumL = 0
  for (const [l, lp, f, d, , sl] of MOON_TERMS) {
    const arg = l*Mpr + lp*Mr + f*Fr + d*Dr   // Ω term omitted (already in Lp)
    let coeff = sl
    if (Math.abs(lp) === 1) coeff *= E
    if (Math.abs(lp) === 2) coeff *= E * E
    sumL += coeff * Math.sin(arg)
  }

  // Additional corrections
  sumL += 3958 * Math.sin(Or) + 1962 * Math.sin(Lr - Fr) + 318 * Math.sin(toRad(normalise(218.316 + 481267.881*T)))

  const moonLon = Lp + sumL / 1_000_000
  return normalise(moonLon)
}

// ---------------------------------------------------------------------------
// Rahu (mean ascending node, Meeus Ch.47)
// ---------------------------------------------------------------------------
function rahuLongitude(jd: number): number {
  const T = julianCenturies(jd)
  const Om = 125.0445479 - 1934.1362608*T + 0.0020754*T*T + T*T*T/467441
  return normalise(Om)
}

// ---------------------------------------------------------------------------
// Keplerian planets (Mercury, Venus, Mars, Jupiter, Saturn)
// ---------------------------------------------------------------------------
function keplerianGeocentricLongitude(body: PlanetBody, jd: number): number {
  const T = julianCenturies(jd)

  // Earth's heliocentric position first
  const [xE, yE] = heliocentricXY('earth', T)

  const el = ELEMENTS[body]
  if (!el) return 0

  const [xP, yP] = heliocentricXYFromElements(el, T)

  // Geocentric ecliptic coordinates
  const dx = xP - xE
  const dy = yP - yE
  return normalise(toDeg(Math.atan2(dy, dx)))
}

function heliocentricXY(body: 'earth', T: number): [number, number] {
  // Earth's orbital elements (approximation)
  const L = toRad(normalise(100.466457 + 36000.7698278*T))
  const M = toRad(normalise(357.529092 + 35999.0502909*T))
  const e = 0.016708634 - 0.000042037*T
  const E = solveKepler(M, e)   // eccentric anomaly (rad)
  const v = 2 * Math.atan2(Math.sqrt(1+e)*Math.sin(E/2), Math.sqrt(1-e)*Math.cos(E/2))
  const r = 1.000001018 * (1 - e*Math.cos(E))
  const lon = toDeg(v) + (toDeg(toRad(normalise(102.937348 + 0.3225557*T))) - toDeg(toRad(normalise(357.529092))))
  return [r*Math.cos(toRad(normalise(lon))), r*Math.sin(toRad(normalise(lon)))]
}

function heliocentricXYFromElements(el: KeplerElements, T: number): [number, number] {
  const L = normalise(el.L0 + el.L1 * T / 36525)
  const omega = normalise(el.P0 + el.P1 * T / 36525)  // longitude of perihelion
  const e = el.e0 + el.e1 * T / 36525
  const M = toRad(normalise(L - omega))
  const E = solveKepler(M, e)
  const r = el.a0 * (1 - e * Math.cos(E))
  const v = 2 * Math.atan2(Math.sqrt(1+e)*Math.sin(E/2), Math.sqrt(1-e)*Math.cos(E/2))
  const lon = normalise(toDeg(v) + omega)
  return [r*Math.cos(toRad(lon)), r*Math.sin(toRad(lon))]
}
