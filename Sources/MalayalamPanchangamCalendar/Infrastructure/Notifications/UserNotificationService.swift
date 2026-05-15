import Foundation
import UserNotifications

actor UserNotificationService: NotificationScheduling {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        if !granted {
            throw PanchangamError.notificationAccessDenied
        }
    }

    func schedule(alert: PanchangamAlert) async throws {
        let content = UNMutableNotificationContent()
        content.title = alert.title
        content.body = alert.body
        if !alert.isSilent {
            content.sound = .default
        }

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: alert.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: alert.id.uuidString, content: content, trigger: trigger)
        try await center.add(request)
    }

    func removePendingAlerts(identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
