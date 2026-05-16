// ─────────────────────────────────────────────────────────────────────────────
// CalendarTab — main calendar screen with month navigation
// ─────────────────────────────────────────────────────────────────────────────

import { useState } from 'react'
import { MonthView } from './MonthView'
import type { PanchangamDay } from '../models/PanchangamDay'
import type { GeoLocation } from '../models/CoreTypes'
import type { PersonProfile } from '../models/FamilyTypes'
import { MALAYALAM_MONTHS } from '../models/MalayalamCalendar'

const MONTH_NAMES = ['January','February','March','April','May','June','July','August','September','October','November','December']

interface Props {
  days: PanchangamDay[]
  isLoading: boolean
  location: GeoLocation
  year: number
  onChangeYear: (y: number) => void
  profiles: PersonProfile[]
  nakshatraInMalayalam: boolean
}

export function CalendarTab({ days, isLoading, location, year, onChangeYear, profiles, nakshatraInMalayalam }: Props) {
  const [month, setMonth] = useState(() => new Date().getMonth())

  function prevMonth() {
    if (month === 0) { setMonth(11); onChangeYear(year - 1) }
    else setMonth(m => m - 1)
  }
  function nextMonth() {
    if (month === 11) { setMonth(0); onChangeYear(year + 1) }
    else setMonth(m => m + 1)
  }

  const mlMonthsThisView = (() => {
    const seen = new Set<number>()
    for (const d of days) {
      const local = new Date(d.date.toLocaleString('en-US', { timeZone: location.timeZoneId }))
      if (local.getFullYear() === year && local.getMonth() === month) {
        seen.add(d.malayalamMonth)
      }
    }
    return [...seen].map(m => MALAYALAM_MONTHS[m].english)
  })()

  // Build sets for birthday and shraddham nakshatra overlays (O(1) cell lookup)
  const birthdayNakshatras = new Set<number>()
  const shraddhamNakshatras = new Set<number>()
  for (const p of profiles) {
    if (!p.isArchived) {
      if (p.birthDetails?.birthNakshatra !== undefined) birthdayNakshatras.add(p.birthDetails.birthNakshatra)
      if (p.deathDetails?.deathNakshatra !== undefined) shraddhamNakshatras.add(p.deathDetails.deathNakshatra)
    }
  }

  return (
    <div className="flex-1 overflow-y-auto">
      {/* Month navigator */}
      <div className="flex items-center justify-between px-4 py-3 sticky top-0 bg-white/90 backdrop-blur-sm border-b border-stone-100 z-10">
        <button onClick={prevMonth} className="w-8 h-8 flex items-center justify-center rounded-full active:bg-stone-100">
          <svg viewBox="0 0 24 24" className="w-5 h-5 text-stone-600" fill="none" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M15 19l-7-7 7-7" />
          </svg>
        </button>

        <div className="text-center">
          <div className="font-semibold text-stone-800">{MONTH_NAMES[month]}</div>
          <div className="text-xs text-stone-500">{year}</div>
          {mlMonthsThisView.length > 0 && (
            <div className="text-[10px] text-kerala-600 font-medium mt-0.5">
              {mlMonthsThisView.join(' · ')}
            </div>
          )}
        </div>

        <button onClick={nextMonth} className="w-8 h-8 flex items-center justify-center rounded-full active:bg-stone-100">
          <svg viewBox="0 0 24 24" className="w-5 h-5 text-stone-600" fill="none" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
          </svg>
        </button>
      </div>

      <div className="px-3 py-3">
        {isLoading ? (
          <div className="flex flex-col items-center justify-center py-20 gap-3">
            <div className="w-8 h-8 border-2 border-kerala-600 border-t-transparent rounded-full animate-spin" />
            <p className="text-stone-500 text-sm">Generating panchangam…</p>
          </div>
        ) : (
          <MonthView
            days={days}
            location={location}
            year={year}
            month={month}
            birthdayNakshatras={birthdayNakshatras}
            shraddhamNakshatras={shraddhamNakshatras}
            nakshatraInMalayalam={nakshatraInMalayalam}
          />
        )}
      </div>

      {/* Legend */}
      {!isLoading && (birthdayNakshatras.size > 0 || shraddhamNakshatras.size > 0) && (
        <div className="flex gap-4 px-4 pb-4 text-xs text-stone-500">
          {birthdayNakshatras.size > 0 && (
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-green-500 inline-block" /> Star birthday
            </span>
          )}
          {shraddhamNakshatras.size > 0 && (
            <span className="flex items-center gap-1">
              <span className="w-2 h-2 rounded-full bg-amber-500 inline-block" /> Śrāddham nakshatra
            </span>
          )}
        </div>
      )}
    </div>
  )
}
