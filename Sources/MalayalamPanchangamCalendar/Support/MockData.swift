import Foundation

enum MockData {
    static let sampleReminder = MalayalamReminder(
        name: "Thiruvonam Birthday",
        kind: .birthday,
        nakshatra: .thiruvonam,
        reminderTime: DateComponents(hour: 7, minute: 30),
        advanceMinutes: 15,
        location: .thrissur
    )

    static let sampleFestival = Festival(
        name: "Vishu Reminder",
        malayalamMonth: .medam,
        malayalamDay: 1,
        notes: "Generated as an individual yearly event, not as a recurring calendar rule."
    )
}
