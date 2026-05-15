# Architecture Overview

## Goals

Malayalam Panchangam Calendar is structured as a native, offline-first macOS app that can evolve from an approximate calculation prototype into a high-precision Swiss Ephemeris backed product without rewriting presentation or reminder workflows.

## Layers

### Domain

`Sources/MalayalamPanchangamCalendar/Domain`

Owns value models and protocols:

- `PanchangamDay`
- `NakshatraPeriod`
- `MalayalamReminder`
- `GeoLocation`
- `ValidationResult`
- `PanchangamAlert`
- `Festival`
- `CalendarEvent`
- `PanchangamCalculator`
- `PanchangamValidator`
- Platform service protocols

The domain layer has no SwiftUI dependency.

### Infrastructure

`Sources/MalayalamPanchangamCalendar/Infrastructure`

Contains replaceable adapters:

- `DefaultPanchangamCalculator`
- `ApproximateAstronomyEngine`
- `RahuPeriodCalculator`
- `MalayalamDateCalculator`
- `FilePanchangamCache`
- `EventKitCalendarService`
- `AppleGeocodingService`
- `UserNotificationService`
- `DefaultPanchangamValidator`

High-precision astronomy should be added here behind existing protocols.

`AstronomicalComputing` is the precision boundary for:

- tropical Sun longitude
- tropical Moon longitude
- Lahiri ayanamsa
- local sunrise and sunset

`ApproximateAstronomyEngine` is the current offline placeholder. It uses a NOAA-style solar day calculation and approximate lunar longitude. `SwissEphemerisAdapter` is reserved for the future C bridge and ephemeris data files.

### Presentation

`Sources/MalayalamPanchangamCalendar/Presentation`

Contains `@Observable` view models and SwiftUI views. Presentation code only asks for year data through `YearGenerationService`, so it does not care whether calculations come from the placeholder engine, Swiss Ephemeris, cached data, or validated fixtures.

## Sample Year-Generation Workflow

1. User selects Gregorian year, location, and calculation mode.
2. `CalendarViewModel.generate(forceRefresh:)` starts an async generation task.
3. `YearGenerationService` checks `PanchangamDayCaching`.
4. If cached data exists, it returns immediately.
5. Otherwise, `PanchangamCalculator.calculateYear` calculates each date.
6. `DefaultPanchangamCalculator` computes sunrise, sunset, nakshatra periods, tithi, Malayalam date fields, Rahu Kalam, Yamagandam, and Gulika Kalam.
7. Results are saved to the offline cache.
8. SwiftUI updates year, month, and day detail surfaces.

## Nakshatra Modes

- Kerala Traditional: sunrise to next sunrise, dominant nakshatra by longest duration.
- Sunrise Nakshatra: nakshatra active at local sunrise.
- Majority Civil Day: dominant nakshatra between local 00:00 and 23:59.

Nakshatra transitions are found by scanning for the next sidereal Moon boundary crossing and refining with binary search. The algorithm is provider-agnostic, so a future Swiss Ephemeris adapter will automatically improve transition times.

## Validation Design

`PanchangamValidator` returns `ValidationResult` with:

- source name
- expected values
- calculated values
- deltas
- pass/fail
- confidence score

`HistoricalArchiveValidationSource` supports fixture injection using keys of the form `location|yyyy-MM-dd`, starting with Thrissur archival fixtures. It can load JSON fixture files through `ValidationFixtureLoader`; see `Docs/ValidationFixtures.md`. Online adapters remain optional so validation never becomes a core-generation dependency.

The day detail screen includes an on-demand validation report. It runs through `PanchangamValidator`, then formats source, confidence, expected values, calculated values, deltas, and pass states without coupling the UI to a specific validation source.

## Apple Calendar Rule

Nakshatra-based reminders must be precomputed into individual `CalendarEvent` values. Do not use EventKit recurring rules for nakshatra events.
