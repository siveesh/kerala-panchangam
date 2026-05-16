import { useState, useCallback } from 'react'
import { CalendarTab } from './components/CalendarTab'
import { FamilyTab } from './components/FamilyTab'
import { SettingsTab } from './components/SettingsTab'
import { usePanchangam } from './hooks/usePanchangam'
import { useProfiles } from './hooks/useProfiles'
import { loadPreferences, savePreferences } from './store/PreferencesStore'
import type { AppPreferences } from './models/CoreTypes'
import type { AppSection } from './models/CoreTypes'

type Tab = 'calendar' | 'family' | 'settings'

const initialPrefs: AppPreferences = loadPreferences()

export default function App() {
  const [tab, setTab] = useState<Tab>('calendar')
  const [prefs, setPrefsState] = useState<AppPreferences>(initialPrefs)

  const handlePrefsChange = useCallback((p: AppPreferences) => {
    setPrefsState(p)
    savePreferences(p)
  }, [])

  const { days, isLoading, year, loadYear } = usePanchangam(prefs)
  const { profiles, saveProfile, deleteProfile, importProfiles, exportProfiles, createProfile } = useProfiles()

  return (
    <div className="flex flex-col h-svh max-w-lg mx-auto bg-stone-50 relative">
      {/* Main content area */}
      <div className="flex-1 flex flex-col overflow-hidden">
        {tab === 'calendar' && (
          <CalendarTab
            days={days}
            isLoading={isLoading}
            location={prefs.location}
            year={year}
            onChangeYear={loadYear}
            profiles={profiles}
          />
        )}
        {tab === 'family' && (
          <FamilyTab
            profiles={profiles}
            days={days}
            onSave={saveProfile}
            onDelete={deleteProfile}
            onImport={importProfiles}
            onExport={exportProfiles}
            createProfile={createProfile}
          />
        )}
        {tab === 'settings' && (
          <SettingsTab prefs={prefs} onChange={handlePrefsChange} />
        )}
      </div>

      {/* Bottom tab bar */}
      <nav className="flex border-t border-stone-200 bg-white safe-bottom">
        <TabItem icon={<CalIcon />} label="Calendar" active={tab === 'calendar'} onClick={() => setTab('calendar')} />
        <TabItem icon={<FamilyIcon />} label="Family"   active={tab === 'family'}   onClick={() => setTab('family')} />
        <TabItem icon={<GearIcon />}  label="Settings"  active={tab === 'settings'} onClick={() => setTab('settings')} />
      </nav>
    </div>
  )
}

function TabItem({ icon, label, active, onClick }: {
  icon: React.ReactNode; label: string; active: boolean; onClick: () => void
}) {
  return (
    <button onClick={onClick} className={`flex-1 flex flex-col items-center justify-center py-2 gap-0.5 transition-colors
      ${active ? 'text-kerala-700' : 'text-stone-400'}`}>
      <span className="w-6 h-6">{icon}</span>
      <span className="text-[10px] font-medium">{label}</span>
    </button>
  )
}

function CalIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} className="w-full h-full">
      <rect x="3" y="4" width="18" height="18" rx="2" />
      <path d="M16 2v4M8 2v4M3 10h18" strokeLinecap="round" />
    </svg>
  )
}
function FamilyIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} className="w-full h-full">
      <path strokeLinecap="round" d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2M9 11a4 4 0 100-8 4 4 0 000 8zM23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75" />
    </svg>
  )
}
function GearIcon() {
  return (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={1.8} className="w-full h-full">
      <circle cx="12" cy="12" r="3" />
      <path strokeLinecap="round" d="M19.4 15a1.65 1.65 0 00.33 1.82l.06.06a2 2 0 010 2.83 2 2 0 01-2.83 0l-.06-.06a1.65 1.65 0 00-1.82-.33 1.65 1.65 0 00-1 1.51V21a2 2 0 01-2 2 2 2 0 01-2-2v-.09A1.65 1.65 0 009 19.4a1.65 1.65 0 00-1.82.33l-.06.06a2 2 0 01-2.83-2.83l.06-.06A1.65 1.65 0 004.68 15a1.65 1.65 0 00-1.51-1H3a2 2 0 01-2-2 2 2 0 012-2h.09A1.65 1.65 0 004.6 9a1.65 1.65 0 00-.33-1.82l-.06-.06a2 2 0 012.83-2.83l.06.06A1.65 1.65 0 009 4.68a1.65 1.65 0 001-1.51V3a2 2 0 012-2 2 2 0 012 2v.09a1.65 1.65 0 001 1.51 1.65 1.65 0 001.82-.33l.06-.06a2 2 0 012.83 2.83l-.06.06A1.65 1.65 0 0019.4 9a1.65 1.65 0 001.51 1H21a2 2 0 012 2 2 2 0 01-2 2h-.09a1.65 1.65 0 00-1.51 1z" />
    </svg>
  )
}
