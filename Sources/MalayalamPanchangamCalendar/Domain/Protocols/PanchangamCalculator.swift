import Foundation

protocol PanchangamCalculator: Sendable {
    func calculateDay(
        date: Date,
        location: GeoLocation,
        mode: CalculationMode
    ) async throws -> PanchangamDay

    func calculateYear(
        year: Int,
        location: GeoLocation,
        mode: CalculationMode
    ) async throws -> [PanchangamDay]
}
