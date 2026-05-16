// ─────────────────────────────────────────────────────────────────────────────
// ICS Calendar Exporter
// Generates RFC 5545-compliant .ics text for family events.
// User downloads and imports into Calendar.app / Google Calendar.
// ─────────────────────────────────────────────────────────────────────────────

import type { FamilyCalendarEvent } from '../models/FamilyTypes'

function pad2(n: number): string { return String(n).padStart(2, '0') }

function icsDate(d: Date): string {
  return `${d.getUTCFullYear()}${pad2(d.getUTCMonth()+1)}${pad2(d.getUTCDate())}T${pad2(d.getUTCHours())}${pad2(d.getUTCMinutes())}00Z`
}

function foldLine(line: string): string {
  // RFC 5545: fold lines longer than 75 octets
  const chunks: string[] = []
  while (line.length > 75) {
    chunks.push(line.slice(0, 75))
    line = ' ' + line.slice(75)
  }
  chunks.push(line)
  return chunks.join('\r\n')
}

function escapeText(s: string): string {
  return s.replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\n/g, '\\n')
}

export function generateIcs(events: FamilyCalendarEvent[], calendarName = 'Malayalam Panchangam'): string {
  const now = icsDate(new Date())
  const vevents = events.map((ev, i) => {
    const uid = `panchangam-${ev.personId}-${i}@web`
    const lines = [
      'BEGIN:VEVENT',
      foldLine(`UID:${uid}`),
      foldLine(`DTSTAMP:${now}`),
      foldLine(`DTSTART:${icsDate(ev.startDate)}`),
      foldLine(`DTEND:${icsDate(ev.endDate)}`),
      foldLine(`SUMMARY:${escapeText(ev.title)}`),
      ev.notes ? foldLine(`DESCRIPTION:${escapeText(ev.notes)}`) : '',
      'END:VEVENT',
    ].filter(Boolean)
    return lines.join('\r\n')
  })

  return [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Malayalam Panchangam Web//EN',
    `X-WR-CALNAME:${calendarName}`,
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    ...vevents,
    'END:VCALENDAR',
  ].join('\r\n')
}

/**
 * Trigger a browser download of the .ics file.
 */
export function downloadIcs(events: FamilyCalendarEvent[], filename = 'panchangam-events.ics'): void {
  const ics = generateIcs(events)
  const blob = new Blob([ics], { type: 'text/calendar;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url
  a.download = filename
  a.click()
  URL.revokeObjectURL(url)
}
