import Foundation

struct TithiCalculator: Sendable {
    func tithi(sunLongitude: Double, moonLongitude: Double) -> Tithi {
        let elongation = (moonLongitude - sunLongitude).normalizedDegrees
        let index = min(29, Int(floor(elongation / Tithi.spanDegrees)))
        return Tithi(rawValue: index) ?? .prathamaShukla
    }
}
