import XCTest
@testable import MalayalamPanchangamCalendar

final class SolarDayTests: XCTestCase {
    func testThrissurSolarDayIsInExpectedRange() throws {
        let engine = ApproximateAstronomyEngine()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = GeoLocation.thrissur.timeZone
        let date = try XCTUnwrap(calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 1, day: 1)))

        let solarDay = try engine.solarDay(for: date, location: .thrissur)
        let sunriseHour = calendar.component(.hour, from: solarDay.sunrise)
        let sunsetHour = calendar.component(.hour, from: solarDay.sunset)

        XCTAssertTrue((6...7).contains(sunriseHour))
        XCTAssertTrue((17...18).contains(sunsetHour))
        XCTAssertGreaterThan(solarDay.sunset.timeIntervalSince(solarDay.sunrise), 11 * 60 * 60)
        XCTAssertLessThan(solarDay.sunset.timeIntervalSince(solarDay.sunrise), 13 * 60 * 60)
    }
}
