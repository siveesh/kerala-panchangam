// ─────────────────────────────────────────────────────────────────────────────
// DayDetailSheet — bottom sheet showing full panchangam detail for one day
// ─────────────────────────────────────────────────────────────────────────────

import type { PanchangamDay } from '../models/PanchangamDay'
import type { GeoLocation } from '../models/CoreTypes'
import { NAKSHATRAS, TITHIS, MALAYALAM_MONTHS } from '../models/MalayalamCalendar'
import { TimeLabel } from './TimeLabel'

interface Props {
  day: PanchangamDay
  location: GeoLocation
  onClose: () => void
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between py-2 border-b border-stone-100 last:border-0">
      <span className="text-stone-500 text-sm">{label}</span>
      <span className="font-medium text-stone-800 text-sm text-right">{value}</span>
    </div>
  )
}

export function DayDetailSheet({ day, location, onClose }: Props) {
  const nak = NAKSHATRAS[day.mainNakshatra]
  const tithi = TITHIS[day.tithi]
  const month = MALAYALAM_MONTHS[day.malayalamMonth]

  const gregDate = day.date.toLocaleDateString('en-IN', {
    timeZone: location.timeZoneId,
    weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  })

  const formatPeriod = (p: { start: Date; end: Date }) => {
    const s = p.start.toLocaleTimeString('en-IN', { timeZone: location.timeZoneId, hour: '2-digit', minute: '2-digit', hour12: true })
    const e = p.end.toLocaleTimeString('en-IN', { timeZone: location.timeZoneId, hour: '2-digit', minute: '2-digit', hour12: true })
    return `${s} – ${e}`
  }

  return (
    <>
      {/* Backdrop */}
      <div className="fixed inset-0 bg-black/40 z-40" onClick={onClose} />

      {/* Sheet */}
      <div className="fixed bottom-0 inset-x-0 z-50 bg-white rounded-t-2xl shadow-2xl max-h-[85vh] overflow-y-auto safe-bottom">
        {/* Handle */}
        <div className="flex justify-center pt-3 pb-1">
          <div className="w-10 h-1 rounded-full bg-stone-300" />
        </div>

        {/* Header */}
        <div className="px-5 py-3 border-b border-stone-100">
          <h2 className="text-base font-semibold text-stone-800 leading-snug">{gregDate}</h2>
          <p className="text-kerala-700 font-medium text-sm mt-0.5">
            {month.english} {day.malayalamDay}, {day.kollavarshamYear}
          </p>
        </div>

        {/* Details */}
        <div className="px-5 py-3">
          <Row label="Nakshatra" value={`${nak.english} / ${nak.malayalam}`} />
          <Row label="Tithi" value={`${tithi.paksha === 'shukla' ? 'Shukla' : 'Krishna'} ${tithi.english}`} />
          <Row label="Sunrise" value={
            day.sunrise.toLocaleTimeString('en-IN', { timeZone: location.timeZoneId, hour: '2-digit', minute: '2-digit', hour12: true })
          } />
          <Row label="Sunset" value={
            day.sunset.toLocaleTimeString('en-IN', { timeZone: location.timeZoneId, hour: '2-digit', minute: '2-digit', hour12: true })
          } />
          <Row label="Rahu Kalam"   value={formatPeriod(day.rahuKalam)} />
          <Row label="Yamagandam"   value={formatPeriod(day.yamagandam)} />
          <Row label="Gulika Kalam" value={formatPeriod(day.gulikaKalam)} />
        </div>

        {/* Close */}
        <div className="px-5 pb-6 pt-2">
          <button
            onClick={onClose}
            className="w-full py-3 rounded-xl bg-kerala-700 text-white font-semibold text-sm active:bg-kerala-800"
          >
            Close
          </button>
        </div>
      </div>
    </>
  )
}
