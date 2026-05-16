// ─────────────────────────────────────────────────────────────────────────────
// Astronomical math utilities
// ─────────────────────────────────────────────────────────────────────────────

export const DEG_TO_RAD = Math.PI / 180
export const RAD_TO_DEG = 180 / Math.PI

export function toRad(deg: number): number { return deg * DEG_TO_RAD }
export function toDeg(rad: number): number { return rad * RAD_TO_DEG }

/** Normalise degrees to [0, 360) */
export function normalise(deg: number): number {
  return ((deg % 360) + 360) % 360
}

/** Julian Day Number from a JS Date (UTC) */
export function julianDay(date: Date): number {
  return date.getTime() / 86_400_000 + 2_440_587.5
}

/** JS Date from Julian Day Number (UTC) */
export function dateFromJulianDay(jd: number): Date {
  return new Date((jd - 2_440_587.5) * 86_400_000)
}

/** Julian centuries from J2000.0 */
export function julianCenturies(jd: number): number {
  return (jd - 2_451_545.0) / 36_525.0
}

/**
 * Date at local midnight for a given calendar date string (YYYY-MM-DD)
 * in the specified IANA timezone, returned as a UTC Date.
 * Uses the Intl API to find midnight in the target TZ.
 */
export function localMidnight(dateStr: string, tzId: string): Date {
  // Parse the date components
  const [year, month, day] = dateStr.split('-').map(Number)
  // Build a Date at midnight UTC first, then adjust
  // The simplest reliable approach: use the Date constructor with a TZ-naive string
  // and correct via the offset difference.
  const utcMidnight = new Date(Date.UTC(year, month - 1, day, 0, 0, 0))
  // Find the offset of the target TZ at that point
  const tzOffset = tzOffsetMinutes(utcMidnight, tzId)
  // Local midnight = UTC midnight minus the offset (so that in that TZ it reads 00:00)
  return new Date(utcMidnight.getTime() - tzOffset * 60_000)
}

/**
 * Returns the UTC offset (in minutes, positive = ahead of UTC) for a given
 * timezone at a given UTC moment, using Intl.DateTimeFormat.
 */
export function tzOffsetMinutes(utcDate: Date, tzId: string): number {
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: tzId,
    year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit',
    hour12: false,
  })
  const parts = Object.fromEntries(fmt.formatToParts(utcDate).map(p => [p.type, p.value]))
  const localMs = Date.UTC(
    Number(parts.year), Number(parts.month) - 1, Number(parts.day),
    Number(parts.hour) % 24, Number(parts.minute), Number(parts.second),
  )
  return Math.round((localMs - utcDate.getTime()) / 60_000)
}

/**
 * Date string "YYYY-MM-DD" for a given UTC Date as seen in a timezone.
 */
export function localDateString(utcDate: Date, tzId: string): string {
  const fmt = new Intl.DateTimeFormat('en-CA', {  // en-CA gives YYYY-MM-DD
    timeZone: tzId,
    year: 'numeric', month: '2-digit', day: '2-digit',
  })
  return fmt.format(utcDate)
}

/**
 * Weekday (1=Sun, 7=Sat) for a UTC Date as seen in the given timezone.
 */
export function localWeekday(utcDate: Date, tzId: string): number {
  const fmt = new Intl.DateTimeFormat('en-US', { timeZone: tzId, weekday: 'short' })
  const day = fmt.format(utcDate)
  const map: Record<string, number> = { Sun:1, Mon:2, Tue:3, Wed:4, Thu:5, Fri:6, Sat:7 }
  return map[day] ?? 1
}

/**
 * Solve Kepler's equation M = E - e·sin(E) for eccentric anomaly E.
 * Uses fixed-point iteration (converges in ~5–10 steps for small e).
 */
export function solveKepler(M: number, e: number): number {
  let E = M
  for (let i = 0; i < 50; i++) {
    const delta = (M - (E - e * Math.sin(E))) / (1 - e * Math.cos(E))
    E += delta
    if (Math.abs(delta) < 1e-10) break
  }
  return E
}
