import XCTest
@testable import MalayalamPanchangamCalendar

final class RahuPeriodTests: XCTestCase {
    private let tz = TimeZone(identifier: "Asia/Kolkata")!
    private let calculator = RahuPeriodCalculator()

    func testRahuPeriodsUseEightEqualDayParts() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        // 2026-01-05 is a Monday
        let date = try XCTUnwrap(calendar.date(from: DateComponents(timeZone: tz, year: 2026, month: 1, day: 5)))
        let sunrise = try XCTUnwrap(calendar.date(from: DateComponents(timeZone: tz, year: 2026, month: 1, day: 5, hour: 6)))
        let sunset = try XCTUnwrap(calendar.date(from: DateComponents(timeZone: tz, year: 2026, month: 1, day: 5, hour: 18)))

        let periods = calculator.periods(for: date, sunrise: sunrise, sunset: sunset, timeZone: tz)

        XCTAssertEqual(periods.rahu.end.timeIntervalSince(periods.rahu.start), 90 * 60, accuracy: 0.1)
        XCTAssertEqual(periods.yamagandam.end.timeIntervalSince(periods.yamagandam.start), 90 * 60, accuracy: 0.1)
        XCTAssertEqual(periods.gulika.end.timeIntervalSince(periods.gulika.start), 90 * 60, accuracy: 0.1)
    }

    // Traditional Kerala Panchangam weekday mappings:
    //   Rahu:      Sun=7, Mon=1, Tue=6, Wed=5, Thu=4, Fri=3, Sat=2
    //   Yamagandam: Sun=4, Mon=3, Tue=2, Wed=1, Thu=7, Fri=6, Sat=5
    //   Gulika:    Sun=6, Mon=5, Tue=4, Wed=3, Thu=2, Fri=1, Sat=7

    func testRahuKalamMondayIsFirstDayPart() throws {
        // Monday: Rahu = part 1 → starts at sunrise (6:00 AM with standard day)
        let (date, sunrise, _) = try standardDay(weekday: 2, month: 1, day: 5, year: 2026)
        let sunset = try makeDate(year: 2026, month: 1, day: 5, hour: 18)
        let periods = calculator.periods(for: date, sunrise: sunrise, sunset: sunset, timeZone: tz)
        XCTAssertEqual(periods.rahu.start.timeIntervalSince(sunrise), 0, accuracy: 1)
    }

    func testRahuKalamSundayIsSeventhDayPart() throws {
        // Sunday: Rahu = part 7 → starts at sunrise + 6 * (day/8)
        // 2026-01-04 is a Sunday
        let date = try makeDate(year: 2026, month: 1, day: 4, hour: 0)
        let sunrise = try makeDate(year: 2026, month: 1, day: 4, hour: 6)
        let sunset = try makeDate(year: 2026, month: 1, day: 4, hour: 18)
        let partLength: TimeInterval = 12 * 3600 / 8
        let expected = sunrise.addingTimeInterval(6 * partLength)
        let periods = calculator.periods(for: date, sunrise: sunrise, sunset: sunset, timeZone: tz)
        XCTAssertEqual(periods.rahu.start.timeIntervalSince(expected), 0, accuracy: 1)
    }

    func testYamagandamWednesdayIsFirstDayPart() throws {
        // Wednesday: Yamagandam = part 1 → starts at sunrise
        // 2026-01-07 is a Wednesday
        let date = try makeDate(year: 2026, month: 1, day: 7, hour: 0)
        let sunrise = try makeDate(year: 2026, month: 1, day: 7, hour: 6)
        let sunset = try makeDate(year: 2026, month: 1, day: 7, hour: 18)
        let periods = calculator.periods(for: date, sunrise: sunrise, sunset: sunset, timeZone: tz)
        XCTAssertEqual(periods.yamagandam.start.timeIntervalSince(sunrise), 0, accuracy: 1)
    }

    func testGulikaKalamFridayIsFirstDayPart() throws {
        // Friday: Gulika = part 1 → starts at sunrise
        // 2026-01-09 is a Friday
        let date = try makeDate(year: 2026, month: 1, day: 9, hour: 0)
        let sunrise = try makeDate(year: 2026, month: 1, day: 9, hour: 6)
        let sunset = try makeDate(year: 2026, month: 1, day: 9, hour: 18)
        let periods = calculator.periods(for: date, sunrise: sunrise, sunset: sunset, timeZone: tz)
        XCTAssertEqual(periods.gulika.start.timeIntervalSince(sunrise), 0, accuracy: 1)
    }

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) throws -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return try XCTUnwrap(cal.date(from: DateComponents(timeZone: tz, year: year, month: month, day: day, hour: hour)))
    }

    private func standardDay(weekday: Int, month: Int, day: Int, year: Int) throws -> (Date, Date, Date) {
        let date = try makeDate(year: year, month: month, day: day, hour: 0)
        let sunrise = try makeDate(year: year, month: month, day: day, hour: 6)
        let sunset = try makeDate(year: year, month: month, day: day, hour: 18)
        return (date, sunrise, sunset)
    }
}
