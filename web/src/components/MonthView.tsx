// ─────────────────────────────────────────────────────────────────────────────
// MonthView — calendar grid for a month
// ─────────────────────────────────────────────────────────────────────────────

import { useState, useMemo } from 'react'
import type { PanchangamDay } from '../models/PanchangamDay'
import type { GeoLocation } from '../models/CoreTypes'
import { NAKSHATRAS, TITHIS } from '../models/MalayalamCalendar'
import { DayDetailSheet } from './DayDetailSheet'

const WEEKDAY_LABELS = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']

interface Props {
  days: PanchangamDay[]
  location: GeoLocation
  year: number
  month: number  // 0-based JS month
  birthdayNakshatras?: Set<number>
  shraddhamNakshatras?: Set<number>
}

export function MonthView({ days, location, year, month, birthdayNakshatras, shraddhamNakshatras }: Props) {
  const [selectedDay, setSelectedDay] = useState<PanchangamDay | null>(null)

  // Filter days for this Gregorian month, using local time
  const monthDays = useMemo(() => {
    return days.filter(d => {
      const local = new Date(d.date.toLocaleString('en-US', { timeZone: location.timeZoneId }))
      return local.getFullYear() === year && local.getMonth() === month
    })
  }, [days, location.timeZoneId, year, month])

  // Map datestring → PanchangamDay for fast lookup
  const dayMap = useMemo(() => {
    const m = new Map<string, PanchangamDay>()
    for (const d of monthDays) {
      const local = new Date(d.date.toLocaleString('en-US', { timeZone: location.timeZoneId }))
      m.set(`${local.getFullYear()}-${local.getMonth()}-${local.getDate()}`, d)
    }
    return m
  }, [monthDays, location.timeZoneId])

  // First day-of-week for this month (0=Sun)
  const firstDow = new Date(year, month, 1).getDay()
  const daysInMonth = new Date(year, month + 1, 0).getDate()

  const cells: (PanchangamDay | null)[] = [
    ...Array(firstDow).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) => dayMap.get(`${year}-${month}-${i + 1}`) ?? null),
  ]

  return (
    <div>
      {/* Day-of-week header */}
      <div className="grid grid-cols-7 mb-1">
        {WEEKDAY_LABELS.map(l => (
          <div key={l} className="text-center text-xs font-medium text-stone-400 py-1">{l}</div>
        ))}
      </div>

      {/* Calendar grid */}
      <div className="grid grid-cols-7 gap-px bg-stone-200 rounded-lg overflow-hidden">
        {cells.map((day, idx) => {
          if (!day) {
            return <div key={`empty-${idx}`} className="bg-white h-16 sm:h-20" />
          }

          const local = new Date(day.date.toLocaleString('en-US', { timeZone: location.timeZoneId }))
          const domDay = local.getDate()
          const nak = NAKSHATRAS[day.mainNakshatra]
          const tithi = TITHIS[day.tithi]
          const isBirthday = birthdayNakshatras?.has(day.mainNakshatra)
          const isShraddham = shraddhamNakshatras?.has(day.mainNakshatra)
          const isToday = local.toDateString() === new Date().toDateString()

          return (
            <button
              key={day.date.getTime()}
              onClick={() => setSelectedDay(day)}
              className="bg-white h-16 sm:h-20 p-1 text-left flex flex-col active:bg-kerala-50 transition-colors relative"
            >
              {/* Gregorian date number */}
              <span className={`text-xs font-semibold w-5 h-5 flex items-center justify-center rounded-full
                ${isToday ? 'bg-kerala-700 text-white' : 'text-stone-700'}`}>
                {domDay}
              </span>

              {/* Malayalam day */}
              <span className="text-[9px] text-kerala-700 font-medium leading-none mt-0.5">
                {day.malayalamDay}
              </span>

              {/* Nakshatra (truncated) */}
              <span className="text-[9px] text-stone-500 leading-none mt-0.5 truncate w-full">
                {nak.english.slice(0, 6)}
              </span>

              {/* Dots for family events */}
              <div className="absolute bottom-1 right-1 flex gap-0.5">
                {isBirthday  && <span className="w-1.5 h-1.5 rounded-full bg-green-500" />}
                {isShraddham && <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />}
              </div>
            </button>
          )
        })}
      </div>

      {/* Day detail bottom sheet */}
      {selectedDay && (
        <DayDetailSheet
          day={selectedDay}
          location={location}
          onClose={() => setSelectedDay(null)}
        />
      )}
    </div>
  )
}
