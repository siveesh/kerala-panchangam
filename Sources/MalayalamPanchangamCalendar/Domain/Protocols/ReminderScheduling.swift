import Foundation

protocol ReminderEventGenerating: Sendable {
    func events(for reminder: MalayalamReminder, in days: [PanchangamDay]) async -> [CalendarEvent]
    func alerts(for reminder: MalayalamReminder, in days: [PanchangamDay]) async -> [PanchangamAlert]
}
