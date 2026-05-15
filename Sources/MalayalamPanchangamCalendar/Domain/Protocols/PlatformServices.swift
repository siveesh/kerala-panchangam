import Foundation

protocol CalendarIntegrating: Sendable {
    func requestAccess() async throws
    func createDedicatedCalendarIfNeeded() async throws -> String
    func addEvents(_ events: [CalendarEvent]) async throws
}

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async throws
    func schedule(alert: PanchangamAlert) async throws
    func removePendingAlerts(identifiers: [String]) async
}

protocol LocationSearching: Sendable {
    func searchCity(_ query: String) async throws -> [GeoLocation]
    func reverseGeocode(latitude: Double, longitude: Double) async throws -> GeoLocation
}

protocol PanchangamDayCaching: Sendable {
    func cachedYear(year: Int, location: GeoLocation, mode: CalculationMode) async throws -> [PanchangamDay]?
    func saveYear(_ days: [PanchangamDay], year: Int, location: GeoLocation, mode: CalculationMode) async throws
}

protocol ReminderStoring: Sendable {
    func loadReminders() async throws -> [MalayalamReminder]
    func saveReminders(_ reminders: [MalayalamReminder]) async throws
}
