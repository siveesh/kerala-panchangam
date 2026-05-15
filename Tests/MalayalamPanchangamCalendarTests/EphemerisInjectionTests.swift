import XCTest
@testable import MalayalamPanchangamCalendar

private struct FixedAstronomy: AstronomicalComputing {
    func tropicalSunLongitude(on date: Date) -> Double { 30 }
    func tropicalMoonLongitude(on date: Date) -> Double { 70 }
    func lahiriAyanamsa(on date: Date) -> Double { 24 }

    func solarDay(for date: Date, location: GeoLocation) throws -> SolarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        let sunrise = try XCTUnwrap(calendar.date(bySettingHour: 6, minute: 0, second: 0, of: date))
        let sunset = try XCTUnwrap(calendar.date(bySettingHour: 18, minute: 0, second: 0, of: date))
        return SolarDay(sunrise: sunrise, sunset: sunset)
    }
}

final class EphemerisInjectionTests: XCTestCase {
    func testCalculatorUsesInjectedAstronomyProvider() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = GeoLocation.thrissur.timeZone
        let date = try XCTUnwrap(calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 1, day: 1)))
        let calculator = DefaultPanchangamCalculator(astronomy: FixedAstronomy())

        let day = try await calculator.calculateDay(date: date, location: .thrissur, mode: .sunriseNakshatra)

        XCTAssertEqual(day.astronomicalData.sunLongitude, 30)
        XCTAssertEqual(day.astronomicalData.moonLongitude, 70)
        XCTAssertEqual(day.astronomicalData.siderealSunLongitude, 6)
        XCTAssertEqual(day.astronomicalData.siderealMoonLongitude, 46)
        XCTAssertEqual(day.tithi, .chaturthiShukla)
    }
}
