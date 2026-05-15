import Foundation

actor YearGenerationService: Sendable {
    private let calculator: PanchangamCalculator
    private let cache: PanchangamDayCaching

    init(
        calculator: PanchangamCalculator = DefaultPanchangamCalculator(),
        cache: PanchangamDayCaching = FilePanchangamCache()
    ) {
        self.calculator = calculator
        self.cache = cache
    }

    func generateYear(year: Int, location: GeoLocation, mode: CalculationMode, forceRefresh: Bool = false) async throws -> [PanchangamDay] {
        if !forceRefresh, let cached = try await cache.cachedYear(year: year, location: location, mode: mode) {
            return cached
        }

        let days = try await calculator.calculateYear(year: year, location: location, mode: mode)
        try await cache.saveYear(days, year: year, location: location, mode: mode)
        return days
    }
}
