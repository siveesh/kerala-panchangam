import Foundation

/// Computes a GrahanilaChart for a given day and time option.
struct GrahanilaCalculationService {

    private let calc = PlanetaryCalculator()
    private let engine = ApproximateAstronomyEngine()

    /// Calculate chart for a PanchangamDay.
    /// - Parameters:
    ///   - day: the selected Panchangam day (used for sunrise time and location)
    ///   - timeOption: sunrise / noon / custom
    ///   - customTime: used only when timeOption == .custom
    ///   - ayanamsa: which ayanamsa correction to apply
    func calculate(
        day: PanchangamDay,
        timeOption: GrahanilaTimeOption,
        customTime: Date? = nil,
        ayanamsa: AyanamsaSelection = .lahiri
    ) -> GrahanilaChart {

        // 1. Determine calculation time
        let calculationTime: Date
        switch timeOption {
        case .sunrise:
            calculationTime = day.sunrise
        case .noon:
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = day.location.timeZone
            let startOfDay = cal.startOfDay(for: day.date)
            calculationTime = startOfDay.addingTimeInterval(12 * 3600)
        case .custom:
            calculationTime = customTime ?? day.sunrise
        }

        // 2. Compute Julian Day
        let jd = PlanetaryCalculator.julianDay(from: calculationTime)

        // 3. Compute ayanamsa in degrees
        let lahiri = engine.lahiriAyanamsa(on: calculationTime)
        let ayanamsaDeg: Double
        switch ayanamsa {
        case .lahiri:
            ayanamsaDeg = lahiri
        case .raman:
            ayanamsaDeg = lahiri - 0.57
        case .krishnamurti:
            ayanamsaDeg = lahiri + 0.25
        }

        // 4. Compute positions for all planets
        var positions: [PlanetPosition] = []
        for planet in Planet.allCases {
            let body = planetBody(for: planet)
            let tropicalLon = calc.tropicalGeocentricLongitude(of: body, julianDay: jd)
            let siderealLon = (tropicalLon - ayanamsaDeg).normalizedDegrees

            // Rahu/Ketu always move retrograde by definition; return false for them
            let retrograde: Bool
            switch planet {
            case .rahu, .ketu:
                retrograde = false
            default:
                retrograde = calc.isRetrograde(body, julianDay: jd)
            }

            let position = PlanetPosition(
                planet: planet,
                tropicalLongitude: tropicalLon,
                siderealLongitude: siderealLon,
                isRetrograde: retrograde
            )
            positions.append(position)
        }

        // 5. Build houses and assign planets
        var houses: [RasiHouse] = Rasi.allCases.map { .empty(rasi: $0) }
        for pos in positions {
            let idx = pos.rasi.rawValue
            let existing = houses[idx].planets
            let sorted = (existing + [pos]).sorted { $0.siderealLongitude < $1.siderealLongitude }
            houses[idx] = RasiHouse(rasi: houses[idx].rasi, planets: sorted)
        }

        // 6. Return the chart
        return GrahanilaChart(
            date: day.date,
            location: day.location,
            calculationTime: calculationTime,
            ayanamsa: ayanamsa,
            houses: houses,
            planetPositions: positions
        )
    }

    // MARK: - Private helpers

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
