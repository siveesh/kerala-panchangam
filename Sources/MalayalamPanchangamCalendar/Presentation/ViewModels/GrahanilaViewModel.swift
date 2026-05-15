import Foundation
import Observation

@MainActor
@Observable
final class GrahanilaViewModel {

    // MARK: - Inputs
    var timeOption: GrahanilaTimeOption = .sunrise
    var customTime: Date = Date()
    var ayanamsaSelection: AyanamsaSelection = .lahiri
    var languagePreference: LanguagePreference = .bilingual

    // MARK: - Output
    var chart: GrahanilaChart?
    var isCalculating = false
    var errorMessage: String?

    // MARK: - Selection state
    var selectedRasi: Rasi?
    var selectedPlanet: PlanetPosition?

    private let service = GrahanilaCalculationService()
    private var currentDay: PanchangamDay?

    // MARK: - Public API

    /// Calculate or recalculate the chart for the given day.
    func calculate(for day: PanchangamDay) async {
        currentDay = day
        isCalculating = true
        errorMessage = nil
        defer { isCalculating = false }
        // Run heavy calculation off main thread
        let chart = await Task.detached(priority: .userInitiated) { [service, timeOption, customTime, ayanamsaSelection, day] in
            service.calculate(day: day, timeOption: timeOption, customTime: customTime, ayanamsa: ayanamsaSelection)
        }.value
        self.chart = chart
    }

    /// Recalculate when time option changes (if we already have a day).
    func recalculate() async {
        guard let day = currentDay else { return }
        await calculate(for: day)
    }

    /// Planet display name based on language preference.
    func name(for planet: Planet) -> String {
        switch languagePreference {
        case .english: planet.englishName
        case .malayalam: planet.malayalamName
        case .bilingual: "\(planet.shortSymbol) \(planet.englishName)"
        }
    }

    /// Rasi display name based on language preference.
    func name(for rasi: Rasi) -> String {
        switch languagePreference {
        case .english: rasi.englishName
        case .malayalam: rasi.malayalamName
        case .bilingual: "\(rasi.malayalamName) / \(rasi.englishName)"
        }
    }

    /// Short planet label for chart cell (always the compact Malayalam symbol).
    func shortLabel(for planet: Planet) -> String { planet.shortSymbol }

    /// Formatted planet longitude string, e.g. "Medam 12°34'"
    func positionSummary(for pos: PlanetPosition) -> String {
        let rasiName: String
        switch languagePreference {
        case .english: rasiName = pos.rasi.englishName
        case .malayalam: rasiName = pos.rasi.malayalamName
        case .bilingual: rasiName = pos.rasi.englishName
        }
        let deg = Int(pos.degreeInRasi)
        let min = Int((pos.degreeInRasi - Double(deg)) * 60)
        let retroStr = pos.isRetrograde ? " ℞" : ""
        return "\(rasiName) \(deg)°\(String(format: "%02d", min))'\(retroStr)"
    }
}
