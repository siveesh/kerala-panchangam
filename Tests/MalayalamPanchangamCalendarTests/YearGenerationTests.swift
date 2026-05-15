import XCTest
@testable import MalayalamPanchangamCalendar

final class YearGenerationTests: XCTestCase {
    func testLeapYearGenerationProduces366Days() async throws {
        let calculator = DefaultPanchangamCalculator()
        let days = try await calculator.calculateYear(year: 2024, location: .thrissur, mode: .keralaTraditional)
        XCTAssertEqual(days.count, 366)
        XCTAssertEqual(days.first?.location.name, "Thrissur")
    }

    func testValidationScaffoldReturnsResult() async throws {
        let calculator = DefaultPanchangamCalculator()
        let day = try await calculator.calculateDay(date: Date(timeIntervalSince1970: 1_704_067_200), location: .thrissur, mode: .keralaTraditional)
        let validator = DefaultPanchangamValidator()
        let result = await validator.validate(day: day)
        XCTAssertEqual(result.sourceName, "No Reference Source")
        XCTAssertFalse(result.passed)
    }
}
