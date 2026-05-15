import XCTest
@testable import MalayalamPanchangamCalendar

final class ReminderPersistenceTests: XCTestCase {
    func testFileReminderStoreRoundTripsReminders() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "Reminders.json")
        let store = FileReminderStore(fileURL: fileURL)
        let reminder = MalayalamReminder(
            name: "Makam Anniversary",
            kind: .deathAnniversary,
            malayalamMonth: .karkidakam,
            malayalamDay: 12,
            nakshatra: .makam,
            reminderTime: DateComponents(hour: 6, minute: 45),
            advanceMinutes: 30,
            location: .thrissur
        )

        try await store.saveReminders([reminder])
        let loaded = try await store.loadReminders()

        XCTAssertEqual(loaded, [reminder])
        try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent())
    }

    func testFileReminderStoreReturnsEmptyWhenMissing() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "Missing.json")
        let store = FileReminderStore(fileURL: fileURL)

        let loaded = try await store.loadReminders()

        XCTAssertTrue(loaded.isEmpty)
    }
}
