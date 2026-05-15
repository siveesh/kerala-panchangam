import XCTest
@testable import MalayalamPanchangamCalendar

final class MalayalamDateTests: XCTestCase {
    func testMalayalamMonthFollowsSiderealSolarSign() throws {
        let calculator = MalayalamDateCalculator()
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let date = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: timeZone, year: 2026, month: 4, day: 14)))

        let medam = try calculator.malayalamDate(for: date, siderealSunLongitude: 2.0, timeZone: timeZone)
        let chingam = try calculator.malayalamDate(for: date, siderealSunLongitude: 122.0, timeZone: timeZone)

        XCTAssertEqual(medam.month, .medam)
        XCTAssertEqual(medam.day, 3)
        XCTAssertEqual(medam.kollavarshamYear, 1201)
        XCTAssertEqual(chingam.month, .chingam)
        XCTAssertEqual(chingam.day, 3)
        XCTAssertEqual(chingam.kollavarshamYear, 1202)
    }

    func testMalayalamDayCanReachLongSolarMonthDates() throws {
        let calculator = MalayalamDateCalculator()
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let date = try XCTUnwrap(Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: timeZone, year: 2026, month: 5, day: 14)))

        let result = try calculator.malayalamDate(for: date, siderealSunLongitude: 29.8, timeZone: timeZone)

        XCTAssertEqual(result.month, .medam)
        XCTAssertEqual(result.day, 31)
    }
}
