import Foundation

actor DefaultPanchangamCalculator: PanchangamCalculator {
    private let astronomy: AstronomicalComputing
    private let rahuCalculator: RahuPeriodCalculator
    private let malayalamDateCalculator: MalayalamDateCalculator
    private let tithiCalculator: TithiCalculator

    // Avoid re-creating Calendar (an expensive struct) on every calculateDay call.
    // Safe inside an actor: single-threaded access is guaranteed.
    private var calendarCache: (tzID: String, calendar: Calendar)?

    init(
        astronomy: AstronomicalComputing = ApproximateAstronomyEngine(),
        rahuCalculator: RahuPeriodCalculator = RahuPeriodCalculator(),
        malayalamDateCalculator: MalayalamDateCalculator = MalayalamDateCalculator(),
        tithiCalculator: TithiCalculator = TithiCalculator()
    ) {
        self.astronomy = astronomy
        self.rahuCalculator = rahuCalculator
        self.malayalamDateCalculator = malayalamDateCalculator
        self.tithiCalculator = tithiCalculator
    }

    func calculateYear(year: Int, location: GeoLocation, mode: CalculationMode) async throws -> [PanchangamDay] {
        let calendar = gregorianCalendar(for: location.timeZone)
        guard
            let start = calendar.date(from: DateComponents(timeZone: location.timeZone, year: year, month: 1, day: 1)),
            let end   = calendar.date(from: DateComponents(timeZone: location.timeZone, year: year + 1, month: 1, day: 1))
        else {
            throw PanchangamError.invalidDate
        }

        var days: [PanchangamDay] = []
        days.reserveCapacity(366)
        var cursor = start
        while cursor < end {
            days.append(try await calculateDay(date: cursor, location: location, mode: mode))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return days
    }

    func calculateDay(date: Date, location: GeoLocation, mode: CalculationMode) async throws -> PanchangamDay {
        let calendar = gregorianCalendar(for: location.timeZone)

        let solar = try astronomy.solarDay(for: date, location: location)
        let nextSolar = try astronomy.solarDay(
            for: calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400),
            location: location
        )

        let civilStart = calendar.startOfDay(for: date)
        let civilEnd   = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: civilStart)
                       ?? civilStart.addingTimeInterval(86_399)

        let nakshatraWindow: DateInterval = switch mode {
        case .keralaTraditional:  DateInterval(start: solar.sunrise, end: nextSolar.sunrise)
        case .sunriseNakshatra:   DateInterval(start: solar.sunrise, end: solar.sunrise.addingTimeInterval(60))
        case .majorityCivilDay:   DateInterval(start: civilStart, end: civilEnd)
        }

        // Ayanamsa computed ONCE per day. It changes ~0.000058° over the 36-hour binary-search
        // window — negligible vs the 0.01° convergence threshold used in refinement.
        let ayanamsa = astronomy.lahiriAyanamsa(on: solar.sunrise)

        let periods    = nakshatraPeriods(in: nakshatraWindow, ayanamsa: ayanamsa)
        let sunriseStar = nakshatra(at: solar.sunrise, ayanamsa: ayanamsa)
        let mainStar   = dominantNakshatra(mode: mode, periods: periods, sunrise: solar.sunrise, ayanamsa: ayanamsa)
        let transition = periods.first { $0.start > nakshatraWindow.start }?.start

        let sunLongitude  = astronomy.tropicalSunLongitude(on: solar.sunrise)
        let moonLongitude = astronomy.tropicalMoonLongitude(on: solar.sunrise)
        let siderealSun   = (sunLongitude  - ayanamsa).normalizedDegrees
        let siderealMoon  = (moonLongitude - ayanamsa).normalizedDegrees

        let malayalam = try malayalamDateCalculator.malayalamDate(
            for: date, siderealSunLongitude: siderealSun, timeZone: location.timeZone)
        let rahu   = rahuCalculator.periods(for: date, sunrise: solar.sunrise, sunset: solar.sunset, timeZone: location.timeZone)
        let tithi  = tithiCalculator.tithi(sunLongitude: sunLongitude, moonLongitude: moonLongitude)

        return PanchangamDay(
            date: calendar.startOfDay(for: date),
            isoDateKey: PanchangamFormatters.dateKey(for: date, timeZone: location.timeZone),
            location: location,
            calculationMode: mode,
            malayalamMonth: malayalam.month,
            malayalamDay: malayalam.day,
            kollavarshamYear: malayalam.kollavarshamYear,
            weekday: PanchangamFormatters.weekday(date, timeZone: location.timeZone),
            sunrise: solar.sunrise,
            sunset: solar.sunset,
            mainNakshatra: mainStar,
            sunriseNakshatra: sunriseStar,
            tithi: tithi,
            nextNakshatra: mainStar.next,
            nakshatraTransition: transition,
            nakshatraPeriods: periods,
            rahuKalam: rahu.rahu,
            yamagandam: rahu.yamagandam,
            gulikaKalam: rahu.gulika,
            astronomicalData: AstronomicalData(
                sunLongitude: sunLongitude,
                moonLongitude: moonLongitude,
                siderealSunLongitude: siderealSun,
                siderealMoonLongitude: siderealMoon,
                lahiriAyanamsa: ayanamsa
            )
        )
    }

    // MARK: - Private helpers

    private func gregorianCalendar(for timeZone: TimeZone) -> Calendar {
        if let cache = calendarCache, cache.tzID == timeZone.identifier {
            return cache.calendar
        }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        calendarCache = (timeZone.identifier, cal)
        return cal
    }

    private func dominantNakshatra(
        mode: CalculationMode,
        periods: [NakshatraPeriod],
        sunrise: Date,
        ayanamsa: Double
    ) -> Nakshatra {
        if mode == .sunriseNakshatra {
            return nakshatra(at: sunrise, ayanamsa: ayanamsa)
        }
        return periods.max(by: { $0.duration < $1.duration })?.nakshatra
            ?? nakshatra(at: sunrise, ayanamsa: ayanamsa)
    }

    private func nakshatra(at date: Date, ayanamsa: Double) -> Nakshatra {
        Nakshatra.from(siderealLongitude: astronomy.tropicalMoonLongitude(on: date) - ayanamsa)
    }

    private func nakshatraPeriods(in window: DateInterval, ayanamsa: Double) -> [NakshatraPeriod] {
        var periods: [NakshatraPeriod] = []
        var cursor  = window.start
        var current = nakshatra(at: cursor, ayanamsa: ayanamsa)

        while cursor < window.end {
            let transition = nextTransition(after: cursor, current: current, ayanamsa: ayanamsa)
            let end = min(transition, window.end)
            periods.append(NakshatraPeriod(nakshatra: current, start: cursor, end: end))
            cursor  = end
            current = current.next
            if transition >= window.end { break }
        }

        return periods
    }

    private func nextTransition(after date: Date, current: Nakshatra, ayanamsa: Double) -> Date {
        // Boundary in sidereal degrees for the next nakshatra.
        // For Revathi (rawValue 26) this is 360° — normalizedDegrees wraps to 0, which is
        // correctly detected as a jump by the remaining > previousRemaining guard below.
        let nextBoundary = Double(current.rawValue + 1) * Nakshatra.spanDegrees
        let initialRemaining = degreesUntilBoundary(at: date, boundary: nextBoundary, ayanamsa: ayanamsa)

        var lower = date
        var upper = date.addingTimeInterval(3_600)
        var previousRemaining = initialRemaining

        while upper.timeIntervalSince(date) <= 36 * 3_600 {
            let remaining = degreesUntilBoundary(at: upper, boundary: nextBoundary, ayanamsa: ayanamsa)
            if remaining > previousRemaining || remaining < 0.01 {
                return refineTransition(lower: lower, upper: upper, boundary: nextBoundary, ayanamsa: ayanamsa)
            }
            lower = upper
            previousRemaining = remaining
            upper = upper.addingTimeInterval(3_600)
        }

        // Fallback: estimate from mean lunar motion (used only when Moon is near apogee and
        // the scan window of 36 h is exhausted without finding the transition).
        let meanLunarMotionDegPerSec = 13.176396 / 86_400
        return date.addingTimeInterval(max(60, initialRemaining / meanLunarMotionDegPerSec))
    }

    private func refineTransition(lower: Date, upper: Date, boundary: Double, ayanamsa: Double) -> Date {
        var low  = lower
        var high = upper
        let lowRemaining = degreesUntilBoundary(at: low, boundary: boundary, ayanamsa: ayanamsa)

        for _ in 0..<32 {
            let mid = Date(timeIntervalSince1970: (low.timeIntervalSince1970 + high.timeIntervalSince1970) / 2)
            let midRemaining = degreesUntilBoundary(at: mid, boundary: boundary, ayanamsa: ayanamsa)
            if midRemaining <= lowRemaining && midRemaining > 0.01 {
                low = mid
            } else {
                high = mid
            }
        }

        return high
    }

    private func degreesUntilBoundary(at date: Date, boundary: Double, ayanamsa: Double) -> Double {
        let siderealMoon = (astronomy.tropicalMoonLongitude(on: date) - ayanamsa).normalizedDegrees
        return (boundary - siderealMoon).normalizedDegrees
    }
}
