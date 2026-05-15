import XCTest
@testable import MalayalamPanchangamCalendar

final class ValidationReportFormatterTests: XCTestCase {
    func testRowsFormatDeltaAndPassState() throws {
        let timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Kolkata"))
        let base = Date(timeIntervalSince1970: 1_767_225_600)
        let result = ValidationResult(
            sourceName: "Fixture",
            expectedValues: ValidationValueSet(
                sunrise: base,
                nakshatra: .atham,
                malayalamMonth: .medam,
                malayalamDay: 1
            ),
            calculatedValues: ValidationValueSet(
                sunrise: base.addingTimeInterval(90),
                nakshatra: .atham,
                malayalamMonth: .medam,
                malayalamDay: 1
            ),
            delta: ValidationDelta(sunriseSeconds: 90),
            passed: true,
            confidenceScore: 0.95
        )

        let rows = ValidationReportFormatter.rows(for: result, timeZone: timeZone)
        let sunrise = try XCTUnwrap(rows.first { $0.id == "sunrise" })
        let nakshatra = try XCTUnwrap(rows.first { $0.id == "nakshatra" })
        let malayalamDate = try XCTUnwrap(rows.first { $0.id == "malayalam-date" })

        XCTAssertEqual(sunrise.delta, "+1m 30s")
        XCTAssertEqual(sunrise.passed, true)
        XCTAssertEqual(nakshatra.expected, "Atham")
        XCTAssertEqual(nakshatra.passed, true)
        XCTAssertEqual(malayalamDate.expected, "Medam 1")
        XCTAssertEqual(malayalamDate.passed, true)
    }
}
