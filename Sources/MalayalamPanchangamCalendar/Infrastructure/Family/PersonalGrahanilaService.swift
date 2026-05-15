import Foundation

// MARK: - PersonalGrahanilaService

/// Calculates and converts Grahanila charts for a person's birth or death record.
/// Uses PlanetaryCalculator directly (same engine as GrahanilaCalculationService)
/// but operates on a plain Date+location rather than a full PanchangamDay.
struct PersonalGrahanilaService: Sendable {

    private let calc = PlanetaryCalculator()
    private let engine = ApproximateAstronomyEngine()

    // MARK: - Calculate PersonGrahanila

    /// Compute planetary positions for the given date/time/location and return
    /// a PersonGrahanila with RasiPlacement entries.
    ///
    /// If `time` is nil, uses noon as the reference time (planetary rāśi positions
    /// are stable across a day for most planets; the chart is marked isEstimated=true).
    ///
    /// Returns nil if insufficient data is available.
    ///
    /// - Important: `time` from a SwiftUI DatePicker(.hourAndMinute) carries the
    ///   date of the day the picker was opened, **not** the birth/death date.
    ///   This method combines only the hour/minute from `time` with the correct
    ///   year/month/day from `date`, in `location.timeZone`.
    func calculate(
        date: Date,
        time: Date?,
        location: GeoLocation,
        ayanamsa: AyanamsaSelection
    ) -> PersonGrahanila? {
        // Determine reference time
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = location.timeZone
        let refTime: Date
        let isEstimated: Bool
        if let time {
            // Merge the correct calendar date with the user-supplied clock time.
            // Only hour/minute from `time` are used; the date part comes from `date`.
            refTime = Self.combine(date: date, time: time, in: location.timeZone)
            isEstimated = false
        } else {
            // Use noon as fallback for unknown birth time
            let midnight = cal.startOfDay(for: date)
            refTime = midnight.addingTimeInterval(12 * 3600)
            isEstimated = true
        }

        let jd = PlanetaryCalculator.julianDay(from: refTime)

        // Compute ayanamsa
        let lahiri = engine.lahiriAyanamsa(on: refTime)
        let ayanamsaDeg: Double
        switch ayanamsa {
        case .lahiri:        ayanamsaDeg = lahiri
        case .raman:         ayanamsaDeg = lahiri - 0.57
        case .krishnamurti:  ayanamsaDeg = lahiri + 0.25
        }

        // Compute sidereal positions for all planets
        var placements: [RasiPlacement] = []
        for planet in Planet.allCases {
            let body = planetBody(for: planet)
            let tropicalLon = calc.tropicalGeocentricLongitude(of: body, julianDay: jd)
            let siderealLon = (tropicalLon - ayanamsaDeg).normalizedDegrees
            let rasi = Rasi.from(siderealLongitude: siderealLon)

            let isRetrograde: Bool
            switch planet {
            case .rahu, .ketu: isRetrograde = false
            default: isRetrograde = calc.isRetrograde(body, julianDay: jd)
            }

            placements.append(RasiPlacement(planet: planet, rasi: rasi, isRetrograde: isRetrograde))
        }

        // Compute lagna if exact time + location are available
        let lagna: Rasi?
        if !isEstimated {
            lagna = approximateLagna(refTime: refTime, location: location, ayanamsaDeg: ayanamsaDeg)
        } else {
            lagna = nil
        }

        let cal2 = Calendar(identifier: .gregorian)
        let components = cal2.dateComponents([.year, .month, .day], from: date)
        let dateKey = String(format: "%04d-%02d-%02d",
                             components.year ?? 0, components.month ?? 0, components.day ?? 0)

        return PersonGrahanila(
            mode: .calculated,
            calculatedPlacements: placements,
            lagna: lagna,
            ayanamsa: ayanamsa,
            calculationDateKey: dateKey,
            isEstimated: isEstimated
        )
    }

    // MARK: - Convert GrahanilaChart → [RasiPlacement]

    /// Convert a full GrahanilaChart (with longitude data) to lightweight RasiPlacements for storage.
    func placements(from chart: GrahanilaChart) -> [RasiPlacement] {
        chart.planetPositions.map { pos in
            RasiPlacement(planet: pos.planet, rasi: pos.rasi, isRetrograde: pos.isRetrograde)
        }
    }

    // MARK: - Approximate Lagna (Ascendant)

    /// Approximates the sidereal lagna (ascendant rasi) using Local Sidereal Time and
    /// the standard trigonometric ascendant formula. Accuracy is ±1 rāśi.
    /// Returns nil if latitude is at or near the poles (|φ| > 66°).
    func approximateLagna(
        refTime: Date,
        location: GeoLocation,
        ayanamsaDeg: Double
    ) -> Rasi? {
        guard abs(location.latitude) <= 66 else { return nil }

        let jd = PlanetaryCalculator.julianDay(from: refTime)
        let T = (jd - 2_451_545.0) / 36_525.0

        // Greenwich Mean Sidereal Time (degrees)
        let gmst = (280.46061837
                    + 360.98564736629 * (jd - 2_451_545.0)
                    + 0.000387933 * T * T
                    - T * T * T / 38_710_000.0).normalizedDegrees

        // Local Sidereal Time
        let lst = (gmst + location.longitude).normalizedDegrees

        // Obliquity of the ecliptic
        let epsilon = (23.4393 - 0.013_004_167 * T).degreesToRadians

        let ramc = lst.degreesToRadians
        let phi  = location.latitude.degreesToRadians

        // Standard ascendant formula
        let y = cos(ramc)
        let x = -(sin(ramc) * cos(epsilon) + tan(phi) * sin(epsilon))
        let tropicalAsc = atan2(y, x).radiansToDegrees.normalizedDegrees

        let siderealAsc = (tropicalAsc - ayanamsaDeg).normalizedDegrees
        return Rasi.from(siderealLongitude: siderealAsc)
    }

    // MARK: - Private helpers

    // MARK: - Date + Time Combiner

    /// Produces a `Date` whose year/month/day comes from `date` and whose
    /// hour/minute/second comes from `time`, all in `timezone`.
    ///
    /// SwiftUI `DatePicker(displayedComponents: .hourAndMinute)` stores today's
    /// date as the base, not the birth or death date. Using this combiner ensures
    /// JD calculations always use the correct full datetime.
    static func combine(date: Date, time: Date, in timezone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone

        let dateParts = cal.dateComponents([.year, .month, .day], from: date)
        let timeParts = cal.dateComponents([.hour, .minute, .second], from: time)

        var merged      = DateComponents()
        merged.year     = dateParts.year
        merged.month    = dateParts.month
        merged.day      = dateParts.day
        merged.hour     = timeParts.hour ?? 0
        merged.minute   = timeParts.minute ?? 0
        merged.second   = timeParts.second ?? 0
        merged.timeZone = timezone

        return cal.date(from: merged) ?? date
    }

    private func planetBody(for planet: Planet) -> PlanetBody {
        switch planet {
        case .sun:     return .sun
        case .moon:    return .moon
        case .mars:    return .mars
        case .mercury: return .mercury
        case .jupiter: return .jupiter
        case .venus:   return .venus
        case .saturn:  return .saturn
        case .rahu:    return .rahu
        case .ketu:    return .ketu
        }
    }
}
