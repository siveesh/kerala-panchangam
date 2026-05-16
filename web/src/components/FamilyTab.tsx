// ─────────────────────────────────────────────────────────────────────────────
// FamilyTab — family profiles list + profile editor
// ─────────────────────────────────────────────────────────────────────────────

import { useState, useRef } from 'react'
import type { PersonProfile } from '../models/FamilyTypes'
import type { PanchangamDay } from '../models/PanchangamDay'
import { NAKSHATRAS, MALAYALAM_MONTHS, TITHIS } from '../models/MalayalamCalendar'
import { birthdayEvents, shraddhamEvents } from '../family/EventGenerator'
import { shraddhamDates } from '../family/ShraddhamFinder'
import { downloadIcs } from '../export/IcsExporter'
import { ProfileEditor } from './ProfileEditor'

interface Props {
  profiles: PersonProfile[]
  days: PanchangamDay[]
  onSave: (p: PersonProfile) => Promise<void>
  onDelete: (id: string) => Promise<void>
  onImport: (json: string) => Promise<void>
  onExport: () => string
  createProfile: () => PersonProfile
}

export function FamilyTab({ profiles, days, onSave, onDelete, onImport, onExport, createProfile }: Props) {
  const [editingProfile, setEditingProfile] = useState<PersonProfile | null>(null)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const activeProfiles = profiles.filter(p => !p.isArchived)
  const living = activeProfiles.filter(p => !p.deathDetails)
  const deceased = activeProfiles.filter(p => p.deathDetails)

  // Upcoming Śrāddham strip
  const upcomingShraddham = activeProfiles
    .filter(p => p.deathDetails)
    .flatMap(p => shraddhamDates(p, days, p.reminderPreferences.shraddhamMode))
    .filter(sd => sd.gregorianDate >= new Date())
    .sort((a, b) => a.gregorianDate.getTime() - b.gregorianDate.getTime())
    .slice(0, 8)

  function handleImportFile(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    const reader = new FileReader()
    reader.onload = ev => {
      const json = ev.target?.result as string
      onImport(json).catch(err => alert('Import failed: ' + err))
    }
    reader.readAsText(file)
    e.target.value = ''
  }

  function handleExportAll() {
    if (days.length === 0) { alert('Load a year first to generate events.'); return }
    const events = activeProfiles.flatMap(p => [
      ...birthdayEvents(p, days),
      ...shraddhamEvents(p, days),
    ])
    if (events.length === 0) { alert('No events to export. Add birth/death details to profiles first.'); return }
    downloadIcs(events, 'panchangam-family-events.ics')
  }

  if (editingProfile) {
    return (
      <ProfileEditor
        profile={editingProfile}
        days={days}
        onSave={async p => { await onSave(p); setEditingProfile(null) }}
        onCancel={() => setEditingProfile(null)}
        onDelete={async id => { await onDelete(id); setEditingProfile(null) }}
      />
    )
  }

  return (
    <div className="flex-1 overflow-y-auto">
      {/* Header toolbar */}
      <div className="flex items-center justify-between px-4 py-3 border-b border-stone-100 sticky top-0 bg-white/90 backdrop-blur-sm z-10">
        <h1 className="font-semibold text-stone-800">Family</h1>
        <div className="flex gap-2">
          <button onClick={() => fileInputRef.current?.click()} title="Restore backup"
            className="w-8 h-8 flex items-center justify-center rounded-full active:bg-stone-100 text-stone-500">
            <svg viewBox="0 0 24 24" className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M3 16v2a2 2 0 002 2h14a2 2 0 002-2v-2M16 8l-4-4-4 4M12 4v12" />
            </svg>
          </button>
          <button onClick={() => { const j = onExport(); downloadBlob(j, 'panchangam-backup.json', 'application/json') }}
            title="Export backup"
            className="w-8 h-8 flex items-center justify-center rounded-full active:bg-stone-100 text-stone-500">
            <svg viewBox="0 0 24 24" className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={1.8}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M3 16v2a2 2 0 002 2h14a2 2 0 002-2v-2M8 12l4 4 4-4M12 4v12" />
            </svg>
          </button>
          <button onClick={() => setEditingProfile(createProfile())}
            className="w-8 h-8 flex items-center justify-center rounded-full bg-kerala-700 text-white active:bg-kerala-800">
            <svg viewBox="0 0 24 24" className="w-5 h-5" fill="none" stroke="currentColor" strokeWidth={2}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M12 4v16M4 12h16" />
            </svg>
          </button>
        </div>
        <input ref={fileInputRef} type="file" accept=".json" className="hidden" onChange={handleImportFile} />
      </div>

      {/* Śrāddham strip */}
      {upcomingShraddham.length > 0 && (
        <div className="px-4 py-2 border-b border-amber-100 bg-amber-50">
          <p className="text-xs font-semibold text-amber-700 mb-1.5">Upcoming Śrāddham Dates</p>
          <div className="flex gap-2 overflow-x-auto pb-1 no-scrollbar">
            {upcomingShraddham.map(sd => (
              <div key={sd.id} className="shrink-0 bg-white rounded-lg border border-amber-200 px-2.5 py-1.5 text-xs">
                <div className="font-medium text-stone-800">{sd.personName}</div>
                <div className="text-stone-500">{sd.gregorianDate.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' })}</div>
                <div className="text-amber-600">{sd.malayalamDateLabel}</div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Export events button */}
      {activeProfiles.length > 0 && (
        <div className="px-4 py-3 border-b border-stone-100">
          <button onClick={handleExportAll}
            className="w-full py-2.5 rounded-xl border border-kerala-300 text-kerala-700 font-medium text-sm active:bg-kerala-50 flex items-center justify-center gap-2">
            <svg viewBox="0 0 24 24" className="w-4 h-4" fill="none" stroke="currentColor" strokeWidth={2}>
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
              <path d="M16 2v4M8 2v4M3 10h18" />
            </svg>
            Export All Events (.ics)
          </button>
        </div>
      )}

      {/* Profile list */}
      {activeProfiles.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-24 gap-3 text-stone-400">
          <svg viewBox="0 0 24 24" className="w-12 h-12" fill="none" stroke="currentColor" strokeWidth={1.2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2M9 11a4 4 0 100-8 4 4 0 000 8zM23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
          </svg>
          <p className="text-sm">No profiles yet — tap + to add</p>
        </div>
      ) : (
        <div className="divide-y divide-stone-100">
          {activeProfiles.map(p => (
            <ProfileRow key={p.id} profile={p} onEdit={() => setEditingProfile({ ...p })} />
          ))}
        </div>
      )}
    </div>
  )
}

function ProfileRow({ profile, onEdit }: { profile: PersonProfile; onEdit: () => void }) {
  const nak = profile.birthDetails?.birthNakshatra !== undefined
    ? NAKSHATRAS[profile.birthDetails.birthNakshatra].english
    : null
  const name = profile.nickname.trim() !== '' ? profile.nickname : profile.fullName
  const deceased = !!profile.deathDetails

  return (
    <button onClick={onEdit} className="w-full flex items-center gap-3 px-4 py-3 active:bg-stone-50 text-left">
      <div className={`w-9 h-9 rounded-full flex items-center justify-center flex-shrink-0 ${deceased ? 'bg-stone-100' : 'bg-kerala-100'}`}>
        <svg viewBox="0 0 24 24" className={`w-5 h-5 ${deceased ? 'text-stone-400' : 'text-kerala-700'}`} fill="currentColor">
          <path d="M12 12c2.7 0 4.8-2.1 4.8-4.8S14.7 2.4 12 2.4 7.2 4.5 7.2 7.2 9.3 12 12 12zm0 2.4c-3.2 0-9.6 1.6-9.6 4.8v2.4h19.2v-2.4c0-3.2-6.4-4.8-9.6-4.8z" />
        </svg>
      </div>
      <div className="flex-1 min-w-0">
        <div className="font-medium text-stone-800 truncate">{name}</div>
        <div className="text-xs text-stone-400 flex gap-2 mt-0.5">
          {profile.relationshipTag && <span>{profile.relationshipTag}</span>}
          {nak && <span>★ {nak}</span>}
          {deceased && <span>🍃 Deceased</span>}
        </div>
      </div>
      <svg viewBox="0 0 24 24" className="w-4 h-4 text-stone-300 flex-shrink-0" fill="none" stroke="currentColor" strokeWidth={2}>
        <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
      </svg>
    </button>
  )
}

function downloadBlob(content: string, filename: string, mime: string) {
  const blob = new Blob([content], { type: mime })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = filename; a.click()
  URL.revokeObjectURL(url)
}
