// ─────────────────────────────────────────────────────────────────────────────
// SettingsTab — location, calculation mode, language, nakshatra policy, Śrāddham
// ─────────────────────────────────────────────────────────────────────────────

import type { AppPreferences, GeoLocation, CalculationMode } from '../models/CoreTypes'
import { KERALA_DISTRICTS, MAJOR_CITIES, INTERNATIONAL_CITIES } from '../models/CoreTypes'

interface Props {
  prefs: AppPreferences
  onChange: (p: AppPreferences) => void
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div className="mb-5">
      <h3 className="text-xs font-semibold uppercase tracking-wider text-stone-400 mb-2 px-1">{title}</h3>
      <div className="bg-white rounded-xl overflow-hidden divide-y divide-stone-100 border border-stone-100">{children}</div>
    </div>
  )
}

function Row({ label, hint, children }: { label: string; hint?: string; children: React.ReactNode }) {
  return (
    <div className="px-4 py-3">
      <div className="flex items-center gap-3">
        <span className="text-sm text-stone-500 w-28 flex-shrink-0">{label}</span>
        <div className="flex-1">{children}</div>
      </div>
      {hint && <p className="text-[10px] text-stone-400 mt-1 ml-[7.5rem]">{hint}</p>}
    </div>
  )
}

function Toggle({ value, onChange }: { value: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      onClick={() => onChange(!value)}
      className={`w-11 h-6 rounded-full transition-colors ${value ? 'bg-kerala-600' : 'bg-stone-300'} relative`}>
      <span className={`absolute top-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${value ? 'translate-x-5' : 'translate-x-0.5'}`} />
    </button>
  )
}

const selectCls = 'w-full text-sm text-stone-800 outline-none bg-transparent'

export function SettingsTab({ prefs, onChange }: Props) {
  const set = (changes: Partial<AppPreferences>) => onChange({ ...prefs, ...changes })

  const allLocations = [...KERALA_DISTRICTS, ...MAJOR_CITIES, ...INTERNATIONAL_CITIES]

  return (
    <div className="flex-1 overflow-y-auto px-4 py-4">
      <h1 className="font-semibold text-stone-800 mb-4">Settings</h1>

      {/* ── Location ─────────────────────────────────────────── */}
      <Section title="Location">
        <Row label="District / City">
          <select className={selectCls} value={prefs.location.name}
            onChange={e => {
              const loc = allLocations.find(l => l.name === e.target.value)
              if (loc) set({ location: loc })
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

      {/* ── Calculation ─────────────────────────────────────── */}
      <Section title="Calculation">
        <Row label="Mode"
          hint="Kerala Traditional: nakshatra at sunrise. Majority Civil Day: nakshatra covering the most daylight hours.">
          <select className={selectCls} value={prefs.calculationMode}
            onChange={e => set({ calculationMode: e.target.value as CalculationMode })}>
            <option value="keralaTraditional">Kerala Traditional</option>
            <option value="sunriseNakshatra">Sunrise Nakshatra</option>
            <option value="majorityCivilDay">Majority Civil Day</option>
          </select>
        </Row>
      </Section>

      {/* ── Calendar Display ─────────────────────────────────── */}
      <Section title="Calendar Display">
        <Row label="Nakshatra Script"
          hint="Show nakshatra names in Malayalam script on calendar cells.">
          <Toggle value={prefs.nakshatraInMalayalam} onChange={v => set({ nakshatraInMalayalam: v })} />
        </Row>
      </Section>

      {/* ── Family Defaults ──────────────────────────────────── */}
      <Section title="Family Defaults">
        <Row label="Duplicate Nakshatra"
          hint="What to observe when the birth nakshatra occurs twice in the birth month. 'Always Second' is the Kerala community standard for auspicious events (confirmed by astrologer).">
          <select className={selectCls} value={prefs.defaultNakshatraPolicy}
            onChange={e => set({ defaultNakshatraPolicy: e.target.value as any })}>
            <option value="alwaysSecond">Always Second (community standard)</option>
            <option value="alwaysFirst">Always First</option>
            <option value="longestDuration">Longest Duration</option>
            <option value="preferSecondUnlessShort">Prefer Second (unless short)</option>
          </select>
        </Row>

        <Row label="Śrāddham Mode"
          hint="How to determine the annual Śrāddham observance date. Kerala tradition uses the death nakshatra (first occurrence in death month).">
          <select className={selectCls} value={prefs.defaultShraddhamMode}
            onChange={e => set({ defaultShraddhamMode: e.target.value as any })}>
            <option value="nakshatraOnly">Nakshatra Only (Kerala traditional)</option>
            <option value="nakshatraPreferred">Nakshatra, fallback to Tithi</option>
            <option value="tithiPreferred">Tithi, fallback to Nakshatra</option>
            <option value="tithiAndNakshatra">Both Nakshatra + Tithi dates</option>
          </select>
        </Row>
      </Section>

      {/* ── About ───────────────────────────────────────────── */}
      <Section title="About">
        <Row label="App"><span className="text-sm text-stone-400">Malayalam Panchangam Web</span></Row>
        <Row label="Version"><span className="text-sm text-stone-400">1.0.0</span></Row>
        <Row label="Moon accuracy"><span className="text-sm text-stone-400">±0.05° (30-term Meeus Ch.47)</span></Row>
        <Row label="Ayanamsa"><span className="text-sm text-stone-400">Lahiri / Chitrapaksha</span></Row>
        <Row label="Source code">
          <a href="https://github.com/siveesh/kerala-panchangam"
            className="text-sm text-kerala-700 underline" target="_blank" rel="noreferrer">
            github.com/siveesh/kerala-panchangam
          </a>
        </Row>
      </Section>

      <p className="text-xs text-stone-300 text-center pb-8 leading-relaxed">
        Verify Śrāddham and muhurtham dates with a trusted<br />
        astrologer or priest before observing.
      </p>
    </div>
  )
}
