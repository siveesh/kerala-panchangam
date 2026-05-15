import XCTest
@testable import MalayalamPanchangamCalendar

final class AyanamsaTests: XCTestCase {
    // Lahiri Chitrapaksha ayanamsa at J2000.0 (2000-01-01 12:00 UTC) ≈ 23.858°
    // Derived from the Indian Astronomical Ephemeris B1900.0 base (22°27′39.4″ = 22.4609°)
    // plus 100 Julian years of precession at 50.290966″/year.
    // This matches Drik Panchang and traditional Kerala almanac software.
    func testLahiriAyanamsaAtJ2000() {
        let engine = ApproximateAstronomyEngine()
        let j2000 = Date(timeIntervalSince1970: 946_728_000) // 2000-01-01T12:00:00Z
        let ayanamsa = engine.lahiriAyanamsa(on: j2000)
        XCTAssertEqual(ayanamsa, 23.858, accuracy: 0.01,
                       "Lahiri ayanamsa at J2000.0 should be ~23.858° (Drik Panchang / traditional Indian)")
    }

    // Ayanamsa increases by ~50.29"/year ≈ 0.01397°/year.
    // After 25 years (J2000 → 2025), expect ~23.1898 + 0.3493 ≈ 23.539°.
    func testLahiriAyanamsaIncreasesByPrecessionRate() {
        let engine = ApproximateAstronomyEngine()
        let j2000 = Date(timeIntervalSince1970: 946_728_000)
        let twentyFiveYearsLater = j2000.addingTimeInterval(25 * 365.2422 * 86_400)
        let delta = engine.lahiriAyanamsa(on: twentyFiveYearsLater) - engine.lahiriAyanamsa(on: j2000)
        let expected = 25 * (50.290966 / 3600.0)
        XCTAssertEqual(delta, expected, accuracy: 0.001)
    }
}
