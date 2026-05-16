// ─────────────────────────────────────────────────────────────────────────────
// MonthView — calendar grid for a month
// ─────────────────────────────────────────────────────────────────────────────

import { useState, useMemo, useRef, useLayoutEffect } from 'react'
import type { PanchangamDay } from '../models/PanchangamDay'
import type { GeoLocation } from '../models/CoreTypes'
import { NAKSHATRAS, TITHIS } from '../models/MalayalamCalendar'
import { DayDetailSheet } from './DayDetailSheet'

const WEEKDAY_LABELS = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']

interface Props {
  days: PanchangamDay[]
  location: GeoLocation
  year: number
  month: number              // 0-based JS month
  birthdayNakshatras?: Set<number>
  shraddhamNakshatras?: Set<number>
  nakshatraInMalayalam?: boolean
}

export function MonthView({ days, location, year, month, birthdayNakshatras, shraddhamNakshatras, nakshatraInMalayalam = false }: Props) {
  const [selectedDay, setSelectedDay] = useState<PanchangamDay | null>(null)
  const gridRef = useRef<HTMLDivElement>(null)

  // Keep --cal-col in sync with actual column width so responsive CSS can use it
  useLayoutEffect(() => {
    function update() {
      if (!gridRef.current) return
      const colWidth = gridRef.current.offsetWidth / 7
      gridRef.current.style.setProperty('--cal-col', `${colWidth}px`)
    }
    update()
    const ro = new ResizeObserver(update)
    if (gridRef.current) ro.observe(gridRef.current)
    return () => ro.disconnect()
  }, [])

  // Filter days for this Gregorian month using local time
  const monthDays = useMemo(() => {
    return days.filter(d => {
      const local = new Date(d.date.toLocaleString('en-US', { timeZone: location.timeZoneId }))
      return local.getFullYear() === year && local.getMonth() === month
    })
  }, [days, location.timeZoneId, year, month])

  // Map datestring → PanchangamDay for fast O(1) lookup
  const dayMap = useMemo(() => {
    const m = new Map<string, PanchangamDay>()
    for (const d of monthDays) {
      const local = new Date(d.date.toLocaleString('en-US', { timeZone: location.timeZoneId }))
      m.set(`${local.getFullYear()}-${local.getMonth()}-${local.getDate()}`, d)
    }
    return m
  }, [monthDays, location.timeZoneId])

  const firstDow = new Date(year, month, 1).getDay()
  const daysInMonth = new Date(year, month + 1, 0).getDate()

  const cells: (PanchangamDay | null)[] = [
    ...Array(firstDow).fill(null),
    ...Array.from({ length: daysInMonth }, (_, i) =>
      dayMap.get(`${year}-${month}-${i + 1}`) ?? null
    ),
  ]

  // Nakshatra label: Malayalam script when toggled, otherwise short English
  // Malayalam script is very compact (2–4 chars) — fits perfectly in small cells
  // English: use full name, let CSS truncate — better than hard-slicing
  function nakLabel(id: number): string {
    return nakshatraInMalayalam ? NAKSHATRAS[id].malayalam : NAKSHATRAS[id].english
  }

  return (
    <div>
      {/* Day-of-week header */}
      <div className="grid grid-cols-7 mb-1">
        {WEEKDAY_LABELS.map(l => (
          <div key={l} className="text-center text-xs font-medium text-stone-400 py-1">{l}</div>
        ))}
      </div>

      {/* Calendar grid — ref so ResizeObserver can set --cal-col */}
      <div ref={gridRef} className="grid grid-cols-7 gap-px bg-stone-200 rounded-lg overflow-hidden">
        {cells.map((day, idx) => {
          if (!day) return <div key={`e-${idx}`} className="bg-white cal-cell" />

          const local = new Date(day.date.toLocaleString('en-US', { timeZone: location.timeZoneId }))
          const domDay = local.getDate()
          const isBirthday  = birthdayNakshatras?.has(day.mainNakshatra)
          const isShraddham = shraddhamNakshatras?.has(day.mainNakshatra)
          const isToday = local.toDateString() === new Date().toDateString()

          return (
            <button
              key={day.date.getTime()}
              onClick={() => setSelectedDay(day)}
              className="bg-white cal-cell p-1 text-left flex flex-col active:bg-kerala-50 transition-colors relative overflow-hidden"
            >
              {/* Gregorian date number */}
              <span className={`cal-day-num font-semibold w-5 h-5 flex items-center justify-center rounded-full flex-shrink-0
                ${isToday ? 'bg-kerala-700 text-white' : 'text-stone-700'}`}>
                {domDay}
              </span>

              {/* Malayalam day number */}
              <span className="cal-ml-day text-kerala-700 font-medium leading-tight mt-0.5 flex-shrink-0">
                {day.malayalamDay}
              </span>

              {/* Nakshatra name — full, truncated by CSS overflow */}
              <span
                className={`leading-tight mt-0.5 w-full overflow-hidden ${nakshatraInMalayalam ? 'cal-nak-ml' : 'cal-nak'}`}
                style={{
                  color: (isBirthday || isShraddham) ? '#166534' : '#78716c',
                  fontWeight: (isBirthday || isShraddham) ? 600 : 400,
                  // Two-line clamp so long English names wrap rather than disappear
                  display: '-webkit-box',
                  WebkitLineClamp: 2,
                  WebkitBoxOrient: 'vertical' as any,
                }}
              >
                {nakLabel(day.mainNakshatra)}
              </span>

              {/* Family event dots */}
              {(isBirthday || isShraddham) && (
                <div className="absolute bottom-1 right-1 flex gap-0.5">
                  {isBirthday  && <span className="w-1.5 h-1.5 rounded-full bg-green-500" />}
                  {isShraddham && <span className="w-1.5 h-1.5 rounded-full bg-amber-500" />}
                </div>
              )}
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
