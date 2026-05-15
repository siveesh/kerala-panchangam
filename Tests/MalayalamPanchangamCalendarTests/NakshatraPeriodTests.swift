import XCTest
@testable import MalayalamPanchangamCalendar

final class NakshatraPeriodTests: XCTestCase {
    func testKeralaTraditionalNakshatraPeriodsAreContinuous() async throws {
        let calculator = DefaultPanchangamCalculator()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = GeoLocation.thrissur.timeZone
        let date = try XCTUnwrap(calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: 2026, month: 4, day: 14)))

        let day = try await calculator.calculateDay(date: date, location: .thrissur, mode: .keralaTraditional)
        let first = try XCTUnwrap(day.nakshatraPeriods.first)
        let last = try XCTUnwrap(day.nakshatraPeriods.last)

        XCTAssertEqual(first.start.timeIntervalSince(day.sunrise), 0, accuracy: 0.001)
        XCTAssertGreaterThan(last.end.timeIntervalSince(first.start), 23 * 60 * 60)

        for pair in zip(day.nakshatraPeriods, day.nakshatraPeriods.dropFirst()) {
            XCTAssertEqual(pair.0.end.timeIntervalSince(pair.1.start), 0, accuracy: 0.001)
            XCTAssertNotEqual(pair.0.nakshatra, pair.1.nakshatra)
        }
    }
}
