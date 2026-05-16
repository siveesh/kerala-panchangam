// ─────────────────────────────────────────────────────────────────────────────
// ProfileEditor — full-screen form for creating/editing a family profile
// Includes: birth/death date + TIME, manual nakshatra entry, exact-time
// nakshatra calculation, duplicate policy, Śrāddham mode per profile.
// ─────────────────────────────────────────────────────────────────────────────

import { useState } from 'react'
import type { PersonProfile, BirthDetails, DeathDetails } from '../models/FamilyTypes'
import type { PanchangamDay } from '../models/PanchangamDay'
import { NAKSHATRAS, MALAYALAM_MONTHS, TITHIS } from '../models/MalayalamCalendar'
import type { NakshatraId, MalayalamMonthId, TithiId } from '../models/MalayalamCalendar'
import { calculateDay } from '../engine/PanchangamCalculator'
import { DEFAULT_LOCATION } from '../models/CoreTypes'
import { nakshatraFromLongitude } from '../models/MalayalamCalendar'
import { siderealMoonLongitude, lahiriAyanamsa } from '../engine/AstronomyEngine'
import { tropicalGeocentricLongitude } from '../engine/PlanetaryCalculator'
import { julianDay, normalise } from '../utils/math'

interface Props {
  profile: PersonProfile
  days: PanchangamDay[]
  onSave: (p: PersonProfile) => Promise<void>
  onCancel: () => void
  onDelete: (id: string) => Promise<void>
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Convert a UTC ISO string back to local HH:MM in the given timezone for display. */
function isoToLocalHHMM(iso: string | undefined, tzId: string): string {
  if (!iso) return ''
  try {
    const d = new Date(iso)
    const fmt = new Intl.DateTimeFormat('en-US', {
      timeZone: tzId, hour: '2-digit', minute: '2-digit', hour12: false,
    })
    const parts = Object.fromEntries(fmt.formatToParts(d).map(p => [p.type, p.value]))
    // hour12:false on midnight gives "24:00" in some browsers — normalise
    return `${parts.hour === '24' ? '00' : parts.hour}:${parts.minute}`
  } catch {
    return ''
  }
}

// ---------------------------------------------------------------------------
// Layout helpers
// ---------------------------------------------------------------------------
function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mb-5">
      <h3 className="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2 px-1">{title}</h3>
      <div className="bg-white rounded-xl overflow-hidden divide-y divide-stone-100 border border-stone-100">{children}</div>
    </div>
  )
}

function Field({ label, children, hint }: { label: string; children: React.ReactNode; hint?: string }) {
  return (
    <div className="px-4 py-3">
      <div className="flex items-center gap-3">
        <label className="text-sm text-stone-500 w-28 flex-shrink-0">{label}</label>
        <div className="flex-1">{children}</div>
      </div>
      {hint && <p className="text-[10px] text-stone-400 mt-1 ml-[7.5rem]">{hint}</p>}
    </div>
  )
}

const inputCls = 'w-full text-sm text-stone-800 outline-none placeholder:text-stone-300 bg-transparent'
const selectCls = 'w-full text-sm text-stone-800 outline-none bg-transparent'

// ---------------------------------------------------------------------------
// Nakshatra calculation at an exact datetime
// (used when birth/death time is known)
// ---------------------------------------------------------------------------
function nakshatraAtExactTime(isoDatetime: string): NakshatraId {
  const date = new Date(isoDatetime)
  const jd = julianDay(date)
  const ayanamsa = lahiriAyanamsa(date)
  const tropical = tropicalGeocentricLongitude('moon', jd)
  const sidereal = normalise(tropical - ayanamsa)
  return nakshatraFromLongitude(sidereal)
}

// Combine a date string (YYYY-MM-DD) and local time string (HH:MM) into ISO UTC.
// We treat the time as local time in the given timezone (defaults to IST).
function combineDateTimeToISO(dateStr: string, timeStr: string, tzId = 'Asia/Kolkata'): string {
  // Build a timestamp by using Intl to find the UTC equivalent of local midnight + time
  const [h, m] = timeStr.split(':').map(Number)
  // Construct a date-time string that the TZ will parse correctly
  // Use a lookup: find UTC offset for this date in this TZ
  const baseUtc = new Date(dateStr + 'T12:00:00Z') // midday UTC as anchor
  const fmt = new Intl.DateTimeFormat('en-US', {
    timeZone: tzId, year: 'numeric', month: '2-digit', day: '2-digit',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false,
  })
  const parts = Object.fromEntries(fmt.formatToParts(baseUtc).map(p => [p.type, p.value]))
  const tzOffset = (new Date(`${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}:${parts.second}`).getTime() - baseUtc.getTime()) / -60000
  const localMs = new Date(`${dateStr}T${String(h).padStart(2,'0')}:${String(m).padStart(2,'0')}:00`).getTime()
  const utcMs = localMs + tzOffset * 60000
  return new Date(utcMs).toISOString()
}

// ---------------------------------------------------------------------------
// Main component
// ---------------------------------------------------------------------------
export function ProfileEditor({ profile, days, onSave, onCancel, onDelete }: Props) {
  const [draft, setDraft] = useState<PersonProfile>({ ...profile })
  const [birthTimeLocal, setBirthTimeLocal] = useState(() =>
    isoToLocalHHMM(draft.birthDetails?.birthTimeISO, 'Asia/Kolkata')
  )
  const [deathTimeLocal, setDeathTimeLocal] = useState(() =>
    isoToLocalHHMM(draft.deathDetails?.deathTimeISO, 'Asia/Kolkata')
  )
  const [isSaving, setIsSaving] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [isCalculating, setIsCalculating] = useState(false)

  const isNew = !profile.fullName && !profile.nickname
  const name = draft.nickname.trim() || draft.fullName || 'New Profile'

  function update(changes: Partial<PersonProfile>) { setDraft(d => ({ ...d, ...changes })) }

  function updateBirth(changes: Partial<BirthDetails>) {
    setDraft(d => ({
      ...d,
      birthDetails: d.birthDetails
        ? { ...d.birthDetails, ...changes }
        : { dateOfBirth: '', nakshatraEntry: 'unset', tithiEntry: 'unset', ...changes }
    }))
  }

  function updateDeath(changes: Partial<DeathDetails>) {
    setDraft(d => ({
      ...d,
      deathDetails: d.deathDetails ? { ...d.deathDetails, ...changes } : undefined
    }))
  }

  // ---------------------------------------------------------------------------
  // Calculate from date [+ time]
  // ---------------------------------------------------------------------------
  async function calculateBirth() {
    if (!draft.birthDetails?.dateOfBirth) return
    setIsCalculating(true)
    try {
      const loc = DEFAULT_LOCATION
      let nakshatra: NakshatraId
      let isoTime: string | undefined

      if (birthTimeLocal) {
        // Exact time known — compute Moon longitude at that precise moment
        isoTime = combineDateTimeToISO(draft.birthDetails.dateOfBirth, birthTimeLocal, loc.timeZoneId)
        nakshatra = nakshatraAtExactTime(isoTime)
      } else {
        // No time — use sunrise nakshatra (same as macOS app fallback)
        const date = new Date(draft.birthDetails.dateOfBirth + 'T12:00:00Z')
        const day = calculateDay(date, loc)
        nakshatra = day.mainNakshatra
      }

      // Also compute the Malayalam panchangam for date metadata
      const date = new Date(draft.birthDetails.dateOfBirth + 'T12:00:00Z')
      const day = calculateDay(date, loc)

      updateBirth({
        birthNakshatra: nakshatra,
        birthTithi: day.tithi,
        birthPaksha: TITHIS[day.tithi].paksha,
        birthMalayalamMonth: day.malayalamMonth,
        birthMalayalamDay: day.malayalamDay,
        birthKollavarshamYear: day.kollavarshamYear,
        birthTimeISO: isoTime,
        nakshatraEntry: 'calculated',
        tithiEntry: 'calculated',
      })
    } finally {
      setIsCalculating(false)
    }
  }

  async function calculateDeath() {
    if (!draft.deathDetails?.dateOfDeath) return
    setIsCalculating(true)
    try {
      const loc = DEFAULT_LOCATION
      let nakshatra: NakshatraId
      let isoTime: string | undefined

      if (deathTimeLocal) {
        isoTime = combineDateTimeToISO(draft.deathDetails.dateOfDeath, deathTimeLocal, loc.timeZoneId)
        nakshatra = nakshatraAtExactTime(isoTime)
      } else {
        const date = new Date(draft.deathDetails.dateOfDeath + 'T12:00:00Z')
        const day = calculateDay(date, loc)
        nakshatra = day.mainNakshatra
      }

      const date = new Date(draft.deathDetails.dateOfDeath + 'T12:00:00Z')
      const day = calculateDay(date, loc)

      updateDeath({
        deathNakshatra: nakshatra,
        deathTithi: day.tithi,
        deathPaksha: TITHIS[day.tithi].paksha,
        deathMalayalamMonth: day.malayalamMonth,
        deathMalayalamDay: day.malayalamDay,
        deathKollavarshamYear: day.kollavarshamYear,
        deathTimeISO: isoTime,
        nakshatraEntry: 'calculated',
        tithiEntry: 'calculated',
      })
    } finally {
      setIsCalculating(false)
    }
  }

  async function handleSave() {
    if (!draft.fullName.trim() && !draft.nickname.trim()) {
      alert('Please enter a name.'); return
    }
    setIsSaving(true)
    await onSave({ ...draft, updatedAt: new Date().toISOString() })
    setIsSaving(false)
  }

  const bd = draft.birthDetails
  const dd = draft.deathDetails

  return (
    <div className="flex-1 flex flex-col overflow-hidden">
      {/* Header */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-stone-100 sticky top-0 bg-white/90 backdrop-blur-sm z-10">
        <button onClick={onCancel} className="text-kerala-700 font-medium text-sm active:opacity-60">Cancel</button>
        <span className="font-semibold text-stone-800 text-sm truncate max-w-[160px]">{name}</span>
        <button onClick={handleSave} disabled={isSaving}
          className="text-kerala-700 font-semibold text-sm active:opacity-60 disabled:opacity-40">
          {isSaving ? 'Saving…' : 'Save'}
        </button>
      </div>

      <div className="flex-1 overflow-y-auto px-4 py-4">

        {/* ── Identity ─────────────────────────────────────────── */}
        <Section title="Identity">
          <Field label="Full Name">
            <input className={inputCls} placeholder="Full name" value={draft.fullName}
              onChange={e => update({ fullName: e.target.value })} />
          </Field>
          <Field label="Nickname">
            <input className={inputCls} placeholder="Short name shown in calendar" value={draft.nickname}
              onChange={e => update({ nickname: e.target.value })} />
          </Field>
          <Field label="Relationship">
            <input className={inputCls} placeholder="Father, Spouse, Child…" value={draft.relationshipTag}
              onChange={e => update({ relationshipTag: e.target.value })} />
          </Field>
        </Section>

        {/* ── Birth Details ─────────────────────────────────────── */}
        <Section title="Birth Details">
          <Field label="Date of Birth">
            <input className={inputCls} type="date" value={bd?.dateOfBirth ?? ''}
              onChange={e => updateBirth({ dateOfBirth: e.target.value })} />
          </Field>

          <Field label="Time of Birth"
            hint={birthTimeLocal ? 'Nakshatra will be calculated at this exact time (IST).' : 'Optional — if unknown, sunrise nakshatra is used.'}>
            <input className={inputCls} type="time" value={birthTimeLocal}
              onChange={e => setBirthTimeLocal(e.target.value)} />
          </Field>

          {/* Calculate button */}
          {bd?.dateOfBirth && (
            <div className="px-4 py-3">
              <button onClick={calculateBirth} disabled={isCalculating}
                className="w-full py-2.5 rounded-xl bg-kerala-700 text-white text-sm font-semibold active:bg-kerala-800 disabled:opacity-50">
                {isCalculating ? 'Calculating…' : birthTimeLocal ? '★ Calculate (exact time)' : '★ Calculate (sunrise)'}
              </button>
              {bd.nakshatraEntry === 'calculated' && bd.birthNakshatra !== undefined && (
                <p className="text-xs text-kerala-700 mt-2 text-center font-medium">
                  ★ {NAKSHATRAS[bd.birthNakshatra].english} ({NAKSHATRAS[bd.birthNakshatra].malayalam})
                  {bd.birthMalayalamMonth !== undefined && bd.birthMalayalamDay !== undefined && (
                    <> · {MALAYALAM_MONTHS[bd.birthMalayalamMonth].english} {bd.birthMalayalamDay}, {bd.birthKollavarshamYear}</>
                  )}
                  {birthTimeLocal && <> · {birthTimeLocal} IST</>}
                </p>
              )}
            </div>
          )}

          {/* Manual nakshatra entry (always available as override) */}
          <Field label="Nakshatra"
            hint={bd?.nakshatraEntry === 'manual' ? 'Manually set.' : bd?.nakshatraEntry === 'calculated' ? 'Auto-calculated — change to override.' : 'Set manually if birth time is unknown.'}>
            <select className={selectCls}
              value={bd?.birthNakshatra ?? ''}
              onChange={e => updateBirth({
                birthNakshatra: e.target.value !== '' ? Number(e.target.value) as NakshatraId : undefined,
                nakshatraEntry: 'manual'
              })}>
              <option value="">— Not set —</option>
              {NAKSHATRAS.map(n => <option key={n.id} value={n.id}>{n.english} ({n.malayalam})</option>)}
            </select>
          </Field>

          <Field label="Birth Month"
            hint="Malayalam month — set manually or auto-filled by Calculate.">
            <select className={selectCls}
              value={bd?.birthMalayalamMonth ?? ''}
              onChange={e => updateBirth({ birthMalayalamMonth: e.target.value !== '' ? Number(e.target.value) as MalayalamMonthId : undefined })}>
              <option value="">— Not set —</option>
              {MALAYALAM_MONTHS.map(m => <option key={m.id} value={m.id}>{m.english} ({m.malayalam})</option>)}
            </select>
          </Field>
        </Section>

        {/* ── Star Birthday Settings ────────────────────────────── */}
        <Section title="Birthday Settings">
          <Field label="Duplicate Policy"
            hint="What to do when the birth nakshatra appears twice in the birth month. Community standard: Always Second.">
            <select className={selectCls}
              value={draft.reminderPreferences.birthdayNakshatraPolicy}
              onChange={e => update({ reminderPreferences: { ...draft.reminderPreferences, birthdayNakshatraPolicy: e.target.value as any } })}>
              <option value="alwaysSecond">Always Second (community standard)</option>
              <option value="alwaysFirst">Always First</option>
              <option value="longestDuration">Longest Duration</option>
              <option value="preferSecondUnlessShort">Prefer Second (unless short)</option>
            </select>
          </Field>
        </Section>

        {/* ── Deceased Toggle ──────────────────────────────────── */}
        <Section title="Deceased">
          <Field label="Mark as Deceased">
            <button
              onClick={() => {
                if (dd) { update({ deathDetails: undefined }) }
                else { update({ deathDetails: { dateOfDeath: '', nakshatraEntry: 'unset', tithiEntry: 'unset' } }) }
              }}
              className={`w-11 h-6 rounded-full transition-colors ${dd ? 'bg-kerala-600' : 'bg-stone-300'} relative`}
              aria-label="Toggle deceased">
              <span className={`absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${dd ? 'translate-x-5' : 'translate-x-0.5'}`} />
            </button>
          </Field>
        </Section>

        {/* ── Death Details ─────────────────────────────────────── */}
        {dd && (
          <>
            <Section title="Death Details">
              <Field label="Date of Death">
                <input className={inputCls} type="date" value={dd.dateOfDeath}
                  onChange={e => updateDeath({ dateOfDeath: e.target.value })} />
              </Field>

              <Field label="Time of Death"
                hint={deathTimeLocal ? 'Nakshatra will be calculated at this exact time (IST).' : 'Optional — if unknown, sunrise nakshatra is used.'}>
                <input className={inputCls} type="time" value={deathTimeLocal}
                  onChange={e => setDeathTimeLocal(e.target.value)} />
              </Field>

              {dd.dateOfDeath && (
                <div className="px-4 py-3">
                  <button onClick={calculateDeath} disabled={isCalculating}
                    className="w-full py-2.5 rounded-xl bg-kerala-700 text-white text-sm font-semibold active:bg-kerala-800 disabled:opacity-50">
                    {isCalculating ? 'Calculating…' : deathTimeLocal ? '🍃 Calculate (exact time)' : '🍃 Calculate (sunrise)'}
                  </button>
                  {dd.nakshatraEntry === 'calculated' && dd.deathNakshatra !== undefined && (
                    <p className="text-xs text-kerala-700 mt-2 text-center font-medium">
                      🍃 {NAKSHATRAS[dd.deathNakshatra].english} ({NAKSHATRAS[dd.deathNakshatra].malayalam})
                      {dd.deathMalayalamMonth !== undefined && dd.deathMalayalamDay !== undefined && (
                        <> · {MALAYALAM_MONTHS[dd.deathMalayalamMonth].english} {dd.deathMalayalamDay}, {dd.deathKollavarshamYear}</>
                      )}
                      {deathTimeLocal && <> · {deathTimeLocal} IST</>}
                    </p>
                  )}
                </div>
              )}

              <Field label="Death Nakshatra"
                hint="Set manually if exact time is unknown, or auto-filled by Calculate.">
                <select className={selectCls}
                  value={dd.deathNakshatra ?? ''}
                  onChange={e => updateDeath({
                    deathNakshatra: e.target.value !== '' ? Number(e.target.value) as NakshatraId : undefined,
                    nakshatraEntry: 'manual'
                  })}>
                  <option value="">— Not set —</option>
                  {NAKSHATRAS.map(n => <option key={n.id} value={n.id}>{n.english} ({n.malayalam})</option>)}
                </select>
              </Field>

              <Field label="Death Tithi"
                hint="Used for tithi-based Śrāddham calculation.">
                <select className={selectCls}
                  value={dd.deathTithi ?? ''}
                  onChange={e => updateDeath({
                    deathTithi: e.target.value !== '' ? Number(e.target.value) as TithiId : undefined,
                    tithiEntry: 'manual'
                  })}>
                  <option value="">— Not set —</option>
                  {TITHIS.map(t => <option key={t.id} value={t.id}>{t.paksha === 'shukla' ? 'S' : 'K'} {t.english}</option>)}
                </select>
              </Field>

              <Field label="Death Month">
                <select className={selectCls}
                  value={dd.deathMalayalamMonth ?? ''}
                  onChange={e => updateDeath({ deathMalayalamMonth: e.target.value !== '' ? Number(e.target.value) as MalayalamMonthId : undefined })}>
                  <option value="">— Not set —</option>
                  {MALAYALAM_MONTHS.map(m => <option key={m.id} value={m.id}>{m.english} ({m.malayalam})</option>)}
                </select>
              </Field>
            </Section>

            {/* ── Śrāddham Settings ─────────────────────────────── */}
            <Section title="Śrāddham Settings">
              <Field label="Observance Mode"
                hint="Kerala tradition: Nakshatra Only. Tithi-based is also common in some families.">
                <select className={selectCls}
                  value={draft.reminderPreferences.shraddhamMode}
                  onChange={e => update({ reminderPreferences: { ...draft.reminderPreferences, shraddhamMode: e.target.value as any } })}>
                  <option value="nakshatraOnly">Nakshatra Only (Kerala traditional)</option>
                  <option value="nakshatraPreferred">Nakshatra, fallback to Tithi</option>
                  <option value="tithiPreferred">Tithi, fallback to Nakshatra</option>
                  <option value="tithiAndNakshatra">Both Nakshatra + Tithi</option>
                </select>
              </Field>
            </Section>
          </>
        )}

        {/* ── Delete ────────────────────────────────────────────── */}
        {!isNew && (
          <div className="mb-8">
            {showDeleteConfirm ? (
              <div className="bg-red-50 rounded-xl border border-red-200 p-4 text-center">
                <p className="text-sm text-red-700 mb-3">Delete "{name}" and all their data?</p>
                <div className="flex gap-2">
                  <button onClick={() => setShowDeleteConfirm(false)}
                    className="flex-1 py-2 rounded-lg bg-white border border-stone-200 text-stone-600 text-sm">Cancel</button>
                  <button onClick={() => onDelete(profile.id)}
                    className="flex-1 py-2 rounded-lg bg-red-600 text-white text-sm font-medium">Delete</button>
                </div>
              </div>
            ) : (
              <button onClick={() => setShowDeleteConfirm(true)}
                className="w-full py-3 rounded-xl border border-red-200 text-red-600 text-sm font-medium active:bg-red-50">
                Delete Profile
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  )
}
