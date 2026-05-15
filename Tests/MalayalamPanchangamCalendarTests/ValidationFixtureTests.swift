import XCTest
@testable import MalayalamPanchangamCalendar

final class ValidationFixtureTests: XCTestCase {
    func testFixtureBackedValidationCanPass() async throws {
        let calculator = DefaultPanchangamCalculator()
        let day = try await calculator.calculateDay(
            date: Date(timeIntervalSince1970: 1_767_225_600),
            location: .thrissur,
            mode: .keralaTraditional
        )
        let expected = ValidationValueSet(
            sunrise: day.sunrise,
            sunset: day.sunset,
            nakshatra: day.mainNakshatra,
            nakshatraTransition: day.nakshatraTransition,
            malayalamMonth: day.malayalamMonth,
            malayalamDay: day.malayalamDay,
            rahuKalam: day.rahuKalam,
            yamagandam: day.yamagandam,
            gulikaKalam: day.gulikaKalam
        )
        let source = HistoricalArchiveValidationSource.thrissurFixture(day.isoDateKey, expected: expected)
        let validator = DefaultPanchangamValidator(sources: [source])

        let result = await validator.validate(day: day)

        XCTAssertTrue(result.passed)
        XCTAssertEqual(result.sourceName, "Historical Malayalam Calendar Archive")
        XCTAssertEqual(result.confidenceScore, 0.95)
    }
}
