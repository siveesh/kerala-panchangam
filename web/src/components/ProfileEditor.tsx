// ─────────────────────────────────────────────────────────────────────────────
// ProfileEditor — full-screen form for creating/editing a family profile
// ─────────────────────────────────────────────────────────────────────────────

import { useState } from 'react'
import type { PersonProfile, BirthDetails, DeathDetails } from '../models/FamilyTypes'
import type { PanchangamDay } from '../models/PanchangamDay'
import { NAKSHATRAS, MALAYALAM_MONTHS, TITHIS } from '../models/MalayalamCalendar'
import type { NakshatraId, MalayalamMonthId, TithiId } from '../models/MalayalamCalendar'
import { calculateDay } from '../engine/PanchangamCalculator'
import { DEFAULT_LOCATION } from '../models/CoreTypes'
import { nakshatraFromLongitude } from '../models/MalayalamCalendar'
import { siderealMoonLongitude } from '../engine/AstronomyEngine'

interface Props {
  profile: PersonProfile
  days: PanchangamDay[]
  onSave: (p: PersonProfile) => Promise<void>
  onCancel: () => void
  onDelete: (id: string) => Promise<void>
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mb-6">
      <h3 className="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2 px-1">{title}</h3>
      <div className="bg-white rounded-xl overflow-hidden divide-y divide-stone-100 border border-stone-100">{children}</div>
    </div>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center px-4 py-3 gap-3">
      <label className="text-sm text-stone-500 w-28 flex-shrink-0">{label}</label>
      <div className="flex-1">{children}</div>
    </div>
  )
}

const inputCls = 'w-full text-sm text-stone-800 outline-none placeholder:text-stone-300 bg-transparent'
const selectCls = 'w-full text-sm text-stone-800 outline-none bg-transparent'

export function ProfileEditor({ profile, days, onSave, onCancel, onDelete }: Props) {
  const [draft, setDraft] = useState<PersonProfile>({ ...profile })
  const [isSaving, setIsSaving] = useState(false)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [isCalculating, setIsCalculating] = useState(false)

  const isNew = !profile.fullName && !profile.nickname
  const name = draft.nickname.trim() || draft.fullName || 'New Profile'

  function update(changes: Partial<PersonProfile>) {
    setDraft(d => ({ ...d, ...changes }))
  }
  function updateBirth(changes: Partial<BirthDetails>) {
    setDraft(d => ({ ...d, birthDetails: { ...d.birthDetails!, ...changes } }))
  }
  function updateDeath(changes: Partial<DeathDetails>) {
    setDraft(d => ({ ...d, deathDetails: { ...d.deathDetails!, ...changes } }))
  }

  async function calculateBirth() {
    if (!draft.birthDetails?.dateOfBirth) return
    setIsCalculating(true)
    try {
      const date = new Date(draft.birthDetails.dateOfBirth + 'T12:00:00Z')
      const loc = { ...DEFAULT_LOCATION, name: draft.birthDetails.birthLocationName ?? DEFAULT_LOCATION.name }
      const day = calculateDay(date, loc)
      updateBirth({
        birthNakshatra: day.mainNakshatra,
        birthTithi: day.tithi,
        birthPaksha: TITHIS[day.tithi].paksha,
        birthMalayalamMonth: day.malayalamMonth,
        birthMalayalamDay: day.malayalamDay,
        birthKollavarshamYear: day.kollavarshamYear,
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
      const date = new Date(draft.deathDetails.dateOfDeath + 'T12:00:00Z')
      const loc = DEFAULT_LOCATION
      const day = calculateDay(date, loc)
      updateDeath({
        deathNakshatra: day.mainNakshatra,
        deathTithi: day.tithi,
        deathPaksha: TITHIS[day.tithi].paksha,
        deathMalayalamMonth: day.malayalamMonth,
        deathMalayalamDay: day.malayalamDay,
        deathKollavarshamYear: day.kollavarshamYear,
        nakshatraEntry: 'calculated',
        tithiEntry: 'calculated',
      })
    } finally {
      setIsCalculating(false)
    }
  }

  async function handleSave() {
    if (!draft.fullName.trim() && !draft.nickname.trim()) {
      alert('Please enter a name.')
      return
    }
    setIsSaving(true)
    await onSave({ ...draft, updatedAt: new Date().toISOString() })
    setIsSaving(false)
  }

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
        {/* Identity */}
        <Section title="Identity">
          <Field label="Full Name">
            <input className={inputCls} placeholder="Full name" value={draft.fullName}
              onChange={e => update({ fullName: e.target.value })} />
          </Field>
          <Field label="Nickname">
            <input className={inputCls} placeholder="Nickname / short name" value={draft.nickname}
              onChange={e => update({ nickname: e.target.value })} />
          </Field>
          <Field label="Relationship">
            <input className={inputCls} placeholder="Father, Spouse, etc." value={draft.relationshipTag}
              onChange={e => update({ relationshipTag: e.target.value })} />
          </Field>
        </Section>

        {/* Birth Details */}
        <Section title="Birth Details">
          <Field label="Date of Birth">
            <input className={inputCls} type="date" value={draft.birthDetails?.dateOfBirth ?? ''}
              onChange={e => update({ birthDetails: draft.birthDetails
                ? { ...draft.birthDetails, dateOfBirth: e.target.value }
                : { dateOfBirth: e.target.value, nakshatraEntry: 'unset', tithiEntry: 'unset' }
              })} />
          </Field>
          <Field label="Nakshatra">
            <select className={selectCls}
              value={draft.birthDetails?.birthNakshatra ?? ''}
              onChange={e => updateBirth({ birthNakshatra: e.target.value !== '' ? Number(e.target.value) as NakshatraId : undefined, nakshatraEntry: 'manual' })}>
              <option value="">— Not set —</option>
              {NAKSHATRAS.map(n => <option key={n.id} value={n.id}>{n.english}</option>)}
            </select>
          </Field>
          <Field label="Month">
            <select className={selectCls}
              value={draft.birthDetails?.birthMalayalamMonth ?? ''}
              onChange={e => updateBirth({ birthMalayalamMonth: e.target.value !== '' ? Number(e.target.value) as MalayalamMonthId : undefined })}>
              <option value="">— Not set —</option>
              {MALAYALAM_MONTHS.map(m => <option key={m.id} value={m.id}>{m.english}</option>)}
            </select>
          </Field>
          {draft.birthDetails?.dateOfBirth && (
            <div className="px-4 py-3">
              <button onClick={calculateBirth} disabled={isCalculating}
                className="w-full py-2 rounded-lg bg-kerala-700 text-white text-sm font-medium active:bg-kerala-800 disabled:opacity-50">
                {isCalculating ? 'Calculating…' : 'Calculate from Date'}
              </button>
              {draft.birthDetails.nakshatraEntry === 'calculated' && draft.birthDetails.birthNakshatra !== undefined && (
                <p className="text-xs text-kerala-700 mt-1.5 text-center">
                  ★ {NAKSHATRAS[draft.birthDetails.birthNakshatra].english} · {MALAYALAM_MONTHS[draft.birthDetails.birthMalayalamMonth!].english} {draft.birthDetails.birthMalayalamDay} · {draft.birthDetails.birthKollavarshamYear}
                </p>
              )}
            </div>
          )}
        </Section>

        {/* Deceased toggle + Death Details */}
        <Section title="Deceased">
          <Field label="Deceased">
            <button
              onClick={() => {
                if (draft.deathDetails) {
                  update({ deathDetails: undefined })
                } else {
                  update({ deathDetails: { dateOfDeath: '', nakshatraEntry: 'unset', tithiEntry: 'unset' } })
                }
              }}
              className={`w-11 h-6 rounded-full transition-colors ${draft.deathDetails ? 'bg-kerala-600' : 'bg-stone-300'} relative`}
            >
              <span className={`absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${draft.deathDetails ? 'translate-x-5' : 'translate-x-0.5'}`} />
            </button>
          </Field>

          {draft.deathDetails && (
            <>
              <Field label="Date of Death">
                <input className={inputCls} type="date" value={draft.deathDetails.dateOfDeath}
                  onChange={e => updateDeath({ dateOfDeath: e.target.value })} />
              </Field>
              <Field label="Death Nakshatra">
                <select className={selectCls}
                  value={draft.deathDetails.deathNakshatra ?? ''}
                  onChange={e => updateDeath({ deathNakshatra: e.target.value !== '' ? Number(e.target.value) as NakshatraId : undefined, nakshatraEntry: 'manual' })}>
                  <option value="">— Not set —</option>
                  {NAKSHATRAS.map(n => <option key={n.id} value={n.id}>{n.english}</option>)}
                </select>
              </Field>
              <Field label="Death Tithi">
                <select className={selectCls}
                  value={draft.deathDetails.deathTithi ?? ''}
                  onChange={e => updateDeath({ deathTithi: e.target.value !== '' ? Number(e.target.value) as TithiId : undefined, tithiEntry: 'manual' })}>
                  <option value="">— Not set —</option>
                  {TITHIS.map(t => <option key={t.id} value={t.id}>{t.paksha === 'shukla' ? 'S' : 'K'} {t.english}</option>)}
                </select>
              </Field>
              <Field label="Death Month">
                <select className={selectCls}
                  value={draft.deathDetails.deathMalayalamMonth ?? ''}
                  onChange={e => updateDeath({ deathMalayalamMonth: e.target.value !== '' ? Number(e.target.value) as MalayalamMonthId : undefined })}>
                  <option value="">— Not set —</option>
                  {MALAYALAM_MONTHS.map(m => <option key={m.id} value={m.id}>{m.english}</option>)}
                </select>
              </Field>
              {draft.deathDetails.dateOfDeath && (
                <div className="px-4 py-3">
                  <button onClick={calculateDeath} disabled={isCalculating}
                    className="w-full py-2 rounded-lg bg-kerala-700 text-white text-sm font-medium active:bg-kerala-800 disabled:opacity-50">
                    {isCalculating ? 'Calculating…' : 'Calculate from Date'}
                  </button>
                  {draft.deathDetails.nakshatraEntry === 'calculated' && draft.deathDetails.deathNakshatra !== undefined && (
                    <p className="text-xs text-kerala-700 mt-1.5 text-center">
                      🍃 {NAKSHATRAS[draft.deathDetails.deathNakshatra].english} · {MALAYALAM_MONTHS[draft.deathDetails.deathMalayalamMonth!].english} {draft.deathDetails.deathMalayalamDay} · {draft.deathDetails.deathKollavarshamYear}
                    </p>
                  )}
                </div>
              )}
            </>
          )}
        </Section>

        {/* Delete */}
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
