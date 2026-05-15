# Siveesh's Calendar — Kerala Panchangam for macOS

A native macOS application that generates the complete **Kerala-style Panchangam** (traditional Hindu almanac) for any Gregorian year and location, with family profile management, star-birthday and Śrāddham reminders, horoscope (Jātakam) export, and Apple Calendar / Reminders integration.

---

## Features

### Calendar Views
- **Year, Month, Week, and Day** views with Malayalam and English labelling
- Bilingual display: English, Malayalam, or both simultaneously
- Nakshatra, Tithi, Yoga, Karana, and Karanam for every day
- Sunrise and sunset times calculated for the selected location
- **Rahu Kalam, Yamagandam, and Gulika Kalam** with correct traditional weekday mappings
- Malayalam date (Kollavarsham year, month, and day)
- Festival and auspicious day overlays

### Calculation Engine
- Three calculation modes: **Kerala Traditional**, Sunrise Nakshatra, Majority Civil Day
- Lahiri (Chitrapaksha) ayanamsa with configurable alternatives (Raman, Krishnamurti)
- 30-term lunar longitude formula (Meeus Ch. 47) for accurate birth-nakshatra calculation
- Binary-search nakshatra transition refinement (±0.01° accuracy)
- Duplicate-nakshatra policy engine for star-birthday deduplication across five strategies

### Family Profiles
- Store birth and death details for any number of family members
- Automatic calculation of Janma Nakshatra, Tithi, Paksha, and Malayalam date from DOB + location
- Conflict detection when calculated values differ from manually entered ones
- **Grahanila (horoscope chart)** — calculated or fully manual South Indian grid entry
- **Jātakam PDF export** — A4 bilingual horoscope with Malayalam glyphs, planetary chart, and personal details
- Encrypted local storage (AES-256-GCM via macOS Keychain) for all family data

### Reminders & Calendar Integration
- Star-birthday events for each family member — every occurrence in the viewing window
- Annual Śrāddham (death anniversary) dates with four observance modes:
  - Nakshatra Only (Kerala traditional default)
  - Nakshatra Preferred
  - Tithi Preferred
  - Tithi + Nakshatra
- Exports to **Apple Calendar** and **Reminders.app**
- Configurable advance-notice time and reminder window
- Calendar view colour overlays for birth-star and death-star days

### Location
- 14 Kerala districts, major Indian cities, and international presets
- Full location search via CoreLocation / geocoding
- Manual latitude/longitude entry

### Settings
- Calculation mode, ayanamsa, language preference, 24-hour time
- Notifications toggle, Apple Calendar integration toggle
- Duplicate nakshatra policy and threshold
- Śrāddham observance mode
- Validation strictness

---

## Requirements

| | |
|---|---|
| **Platform** | macOS 14.6 Sonoma or later |
| **Architecture** | Apple Silicon (M-series) |
| **Xcode** | 16.0 or later |
| **Swift** | 6.0 |

No third-party dependencies. All frameworks (SwiftUI, EventKit, UserNotifications, CoreLocation, PDFKit, MapKit) are part of the macOS SDK.

---

## Building from Source

```bash
git clone https://github.com/<your-username>/kerala-panchangam.git
cd kerala-panchangam
open MalayalamPanchangamCalendar.xcodeproj
```

Select the **"Siveesh's Calendar"** scheme and press **⌘R**.

To build from the command line (no code signing required):

```bash
xcodebuild build \
  -scheme "Siveesh's Calendar" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

To run tests:

```bash
swift test
```

---

## Project Structure

```
.
├── Sources/
│   └── MalayalamPanchangamCalendar/
│       ├── App/                       Entry point and app-level dependency wiring
│       ├── Domain/
│       │   ├── Models/                Core types — PanchangamDay, Nakshatra, Tithi,
│       │   │                          MalayalamMonth, FamilyTypes, CalendarEvent …
│       │   └── Protocols/             PanchangamCalculator, FamilyStoring,
│       │                              FamilyEventGenerating, ReminderStoring …
│       ├── Infrastructure/
│       │   ├── Calculation/           Astronomical engine, Malayalam date calculator,
│       │   │                          Rahu Kalam, NakshatraOccurrenceAnalyzer …
│       │   ├── Calendar/              EventKit calendar integration
│       │   ├── Family/                FamilyStore, FamilyEventGenerator,
│       │   │                          ShraddhamDateFinder, HoroscopeExporter …
│       │   ├── Geocoding/             CoreLocation geocoding service
│       │   ├── Notifications/         UserNotifications scheduling service
│       │   ├── Persistence/           File-based and encrypted UserDefaults stores
│       │   └── Validation/            Historical fixture validation subsystem
│       └── Presentation/
│           ├── ViewModels/            CalendarViewModel, FamilyViewModel,
│           │                          ReminderViewModel, LocationSearchViewModel …
│           ├── Views/                 SwiftUI views — Calendar, Family, Settings,
│           │                          Reminders, Location, Day detail …
│           └── Settings/              SettingsView
├── WidgetExtension/                   WidgetKit extension (day summary widget)
├── Tests/                             Unit tests
├── Config/                            App and widget entitlements
├── Data/                              Validation fixtures
├── Docs/                              Architecture notes
├── script/                            Build helper scripts
└── MalayalamPanchangamCalendar.xcodeproj
```

---

## Architecture

The app follows a clean **MVVM + layered architecture**:

- **Domain** — pure value types and protocols; no UIKit/AppKit or network dependencies
- **Infrastructure** — concrete implementations (calculation engine, stores, services); all `Sendable` actors/structs for Swift 6 concurrency safety
- **Presentation** — `@Observable @MainActor` view models; SwiftUI views bind to view models only

See [`Docs/Architecture.md`](Docs/Architecture.md) for the full architecture document.

---

## Calculation Notes

The astronomical engine is based on:

- Jean Meeus, *Astronomical Algorithms* (2nd ed.) — Ch. 22 (solar position), Ch. 47 (30-term lunar position)
- Lahiri ayanamsa (Chitrapaksha) at J2000.0 = 23.1898°, precession rate 50.290966 arcsec/year
- Traditional Kerala weekday mappings for Rahu Kalam, Yamagandam, and Gulika Kalam
- Kollavarsham year: gregorianYear − 824 (Chingam–Dhanu) / gregorianYear − 825 (Makaram–Karkidakam)

Accuracy is sufficient for day-level Panchangam generation. A `SwissEphemerisAdapter` stub exists for future high-precision integration.

---

## Privacy

All family profile data is stored **locally on device only**, encrypted with AES-256-GCM using a key stored in the macOS Keychain. No data is ever transmitted to any server.

---

## Known Limitations

- Swiss Ephemeris integration is not yet complete (stub exists; throws `calculationUnavailable`)
- Lagna calculation is approximate (±1 rāśi without precise birth time and location)
- Validation fixture data is minimal — contributions of authoritative Thrissur / Kochi almanac data are welcome

---

## Roadmap

- [ ] Swiss Ephemeris integration for higher-precision planetary positions
- [ ] Universal binary (Intel + Apple Silicon)
- [ ] iCloud sync for family profiles
- [ ] Expanded validation fixtures from published Kerala almanacs
- [ ] Map-based location picker

---

## License

MIT License — see [`LICENSE`](LICENSE) for details.

---

*Built with SwiftUI · Swift 6 · macOS 14.6+*
