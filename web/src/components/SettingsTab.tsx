// ─────────────────────────────────────────────────────────────────────────────
// SettingsTab — location picker, calculation mode, language
// ─────────────────────────────────────────────────────────────────────────────

import type { AppPreferences, GeoLocation, CalculationMode } from '../models/CoreTypes'
import { KERALA_DISTRICTS, MAJOR_CITIES, INTERNATIONAL_CITIES } from '../models/CoreTypes'

interface Props {
  prefs: AppPreferences
  onChange: (p: AppPreferences) => void
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mb-6">
      <h3 className="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2 px-1">{title}</h3>
      <div className="bg-white rounded-xl overflow-hidden divide-y divide-stone-100 border border-stone-100">{children}</div>
    </div>
  )
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex items-center px-4 py-3 gap-3">
      <span className="text-sm text-stone-500 w-28 flex-shrink-0">{label}</span>
      <div className="flex-1">{children}</div>
    </div>
  )
}

const selectCls = 'w-full text-sm text-stone-800 outline-none bg-transparent'

export function SettingsTab({ prefs, onChange }: Props) {
  function setLocation(loc: GeoLocation) { onChange({ ...prefs, location: loc }) }
  function setMode(calculationMode: CalculationMode) { onChange({ ...prefs, calculationMode }) }

  const allLocations: GeoLocation[] = [
    ...KERALA_DISTRICTS,
    ...MAJOR_CITIES,
    ...INTERNATIONAL_CITIES,
  ]

  return (
    <div className="flex-1 overflow-y-auto px-4 py-4">
      <h1 className="font-semibold text-stone-800 mb-4">Settings</h1>

      <Section title="Location">
        <Row label="District / City">
          <select className={selectCls}
            value={prefs.location.name}
            onChange={e => {
              const loc = allLocations.find(l => l.name === e.target.value)
              if (loc) setLocation(loc)
            }}>
            <optgroup label="Kerala Districts">
              {KERALA_DISTRICTS.map(l => <option key={l.name}>{l.name}</option>)}
            </optgroup>
            <optgroup label="Major Cities">
              {MAJOR_CITIES.map(l => <option key={l.name}>{l.name}</option>)}
            </optgroup>
            <optgroup label="International">
              {INTERNATIONAL_CITIES.map(l => <option key={l.name}>{l.name}</option>)}
            </optgroup>
          </select>
        </Row>
        <Row label="Latitude">
          <span className="text-sm text-stone-400">{prefs.location.latitude.toFixed(4)}° N</span>
        </Row>
        <Row label="Longitude">
          <span className="text-sm text-stone-400">{prefs.location.longitude.toFixed(4)}° E</span>
        </Row>
        <Row label="Timezone">
          <span className="text-sm text-stone-400">{prefs.location.timeZoneId}</span>
        </Row>
      </Section>

      <Section title="Calculation">
        <Row label="Mode">
          <select className={selectCls} value={prefs.calculationMode} onChange={e => setMode(e.target.value as CalculationMode)}>
            <option value="keralaTraditional">Kerala Traditional</option>
            <option value="sunriseNakshatra">Sunrise Nakshatra</option>
            <option value="majorityCivilDay">Majority Civil Day</option>
          </select>
        </Row>
      </Section>

      <Section title="About">
        <Row label="App">
          <span className="text-sm text-stone-400">Malayalam Panchangam Web</span>
        </Row>
        <Row label="Version">
          <span className="text-sm text-stone-400">1.0.0</span>
        </Row>
        <Row label="Accuracy">
          <span className="text-sm text-stone-400">Moon ±0.05° (30-term Meeus)</span>
        </Row>
        <Row label="Ayanamsa">
          <span className="text-sm text-stone-400">Lahiri (Chitrapaksha)</span>
        </Row>
      </Section>

      <div className="text-xs text-stone-300 text-center pb-8">
        Verify important dates with a trusted astrologer.<br />
        Especially Śrāddham and muhurtham.
      </div>
    </div>
  )
}
