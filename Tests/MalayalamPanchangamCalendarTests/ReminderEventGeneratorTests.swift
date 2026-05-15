import XCTest
@testable import MalayalamPanchangamCalendar

final class ReminderEventGeneratorTests: XCTestCase {
    func testNakshatraReminderGeneratesIndividualEvents() async throws {
        let calculator = DefaultPanchangamCalculator()
        let days = try await calculator.calculateYear(year: 2026, location: .thrissur, mode: .keralaTraditional)
        let targetStar = try XCTUnwrap(days.first?.mainNakshatra)
        let reminder = MalayalamReminder(
            name: "Star Birthday",
            kind: .birthday,
            nakshatra: targetStar,
            reminderTime: DateComponents(hour: 7, minute: 30),
            advanceMinutes: 15,
            location: .thrissur
        )

        let generator = MalayalamReminderEventGenerator()
        let events = await generator.events(for: reminder, in: days)

        XCTAssertFalse(events.isEmpty)
        XCTAssertTrue(events.allSatisfy { $0.sourceReminderID == reminder.id })
        XCTAssertTrue(events.allSatisfy { $0.notes.contains("not an EventKit recurring rule") })
    }
}
