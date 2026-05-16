// ─────────────────────────────────────────────────────────────────────────────
// Core App Configuration Types
// Ported from CoreTypes.swift
// ─────────────────────────────────────────────────────────────────────────────

export type CalculationMode =
  | 'keralaTraditional'   // Nakshatra at sunrise; if transitions after sunrise, next nakshatra
  | 'sunriseNakshatra'    // Always use nakshatra prevailing at exact sunrise
  | 'majorityCivilDay'    // Nakshatra covering most of the civil day

export type LanguagePreference = 'english' | 'malayalam' | 'bilingual'

export type AyanamsaSelection = 'lahiri' | 'raman' | 'krishnamurti'

export type AppSection = 'calendar' | 'family' | 'settings'

// ---------------------------------------------------------------------------
// Geographic location
// ---------------------------------------------------------------------------
export interface GeoLocation {
  name: string
  latitude: number    // degrees N positive
  longitude: number   // degrees E positive
  timeZoneId: string  // IANA e.g. "Asia/Kolkata"
  elevation?: number  // metres above sea level
}

// ---------------------------------------------------------------------------
// Kerala district presets
// ---------------------------------------------------------------------------
export const KERALA_DISTRICTS: GeoLocation[] = [
  { name: 'Thiruvananthapuram', latitude: 8.5241,  longitude: 76.9366, timeZoneId: 'Asia/Kolkata' },
  { name: 'Kollam',             latitude: 8.8932,  longitude: 76.6141, timeZoneId: 'Asia/Kolkata' },
  { name: 'Pathanamthitta',     latitude: 9.2648,  longitude: 76.7870, timeZoneId: 'Asia/Kolkata' },
  { name: 'Alappuzha',          latitude: 9.4981,  longitude: 76.3388, timeZoneId: 'Asia/Kolkata' },
  { name: 'Kottayam',           latitude: 9.5916,  longitude: 76.5222, timeZoneId: 'Asia/Kolkata' },
  { name: 'Idukki',             latitude: 9.9189,  longitude: 77.1025, timeZoneId: 'Asia/Kolkata' },
  { name: 'Ernakulam',          latitude: 9.9816,  longitude: 76.2999, timeZoneId: 'Asia/Kolkata' },
  { name: 'Thrissur',           latitude: 10.5276, longitude: 76.2144, timeZoneId: 'Asia/Kolkata' },
  { name: 'Palakkad',           latitude: 10.7867, longitude: 76.6548, timeZoneId: 'Asia/Kolkata' },
  { name: 'Malappuram',         latitude: 11.0510, longitude: 76.0711, timeZoneId: 'Asia/Kolkata' },
  { name: 'Kozhikode',          latitude: 11.2588, longitude: 75.7804, timeZoneId: 'Asia/Kolkata' },
  { name: 'Wayanad',            latitude: 11.6854, longitude: 76.1320, timeZoneId: 'Asia/Kolkata' },
  { name: 'Kannur',             latitude: 11.8745, longitude: 75.3704, timeZoneId: 'Asia/Kolkata' },
  { name: 'Kasaragod',          latitude: 12.4996, longitude: 74.9869, timeZoneId: 'Asia/Kolkata' },
]

export const MAJOR_CITIES: GeoLocation[] = [
  { name: 'Chennai',    latitude: 13.0827, longitude: 80.2707, timeZoneId: 'Asia/Kolkata' },
  { name: 'Bengaluru',  latitude: 12.9716, longitude: 77.5946, timeZoneId: 'Asia/Kolkata' },
  { name: 'Mumbai',     latitude: 19.0760, longitude: 72.8777, timeZoneId: 'Asia/Kolkata' },
  { name: 'Delhi',      latitude: 28.6139, longitude: 77.2090, timeZoneId: 'Asia/Kolkata' },
  { name: 'Hyderabad',  latitude: 17.3850, longitude: 78.4867, timeZoneId: 'Asia/Kolkata' },
  { name: 'Kolkata',    latitude: 22.5726, longitude: 88.3639, timeZoneId: 'Asia/Kolkata' },
  { name: 'Pune',       latitude: 18.5204, longitude: 73.8567, timeZoneId: 'Asia/Kolkata' },
]

export const INTERNATIONAL_CITIES: GeoLocation[] = [
  { name: 'Dubai',        latitude: 25.2048, longitude: 55.2708, timeZoneId: 'Asia/Dubai'      },
  { name: 'Singapore',    latitude: 1.3521,  longitude: 103.8198,timeZoneId: 'Asia/Singapore'  },
  { name: 'London',       latitude: 51.5074, longitude: -0.1278, timeZoneId: 'Europe/London'   },
  { name: 'New York',     latitude: 40.7128, longitude: -74.0060,timeZoneId: 'America/New_York'},
  { name: 'Toronto',      latitude: 43.6532, longitude: -79.3832,timeZoneId: 'America/Toronto' },
  { name: 'Sydney',       latitude: -33.8688,longitude: 151.2093,timeZoneId: 'Australia/Sydney'},
  { name: 'Kuala Lumpur', latitude: 3.1390,  longitude: 101.6869,timeZoneId: 'Asia/Kuala_Lumpur'},
]

export const DEFAULT_LOCATION: GeoLocation = KERALA_DISTRICTS[7] // Thrissur

// ---------------------------------------------------------------------------
// App preferences (persisted to localStorage)
// ---------------------------------------------------------------------------
export interface AppPreferences {
  location: GeoLocation
  calculationMode: CalculationMode
  language: LanguagePreference
  ayanamsa: AyanamsaSelection
}

export const DEFAULT_PREFERENCES: AppPreferences = {
  location: DEFAULT_LOCATION,
  calculationMode: 'keralaTraditional',
  language: 'english',
  ayanamsa: 'lahiri',
}
