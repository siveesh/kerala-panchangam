import Foundation
import Observation

struct ReminderDraft: Equatable, Sendable {
    var id: UUID?
    var name: String = ""
    var kind: ReminderKind = .birthday
    var usesMalayalamDate = false        // exact day: specific month + day number
    var usesMalayalamMonth = false       // month restriction: nakshatra in a specific month (once/year)
    var malayalamMonth: MalayalamMonth = .chingam
    var malayalamDay: Int = 1
    var usesNakshatra = true
    var nakshatra: Nakshatra = .thiruvonam
    var hour: Int = 7
    var minute: Int = 0
    var advanceMinutes: Int = 15
    var location: GeoLocation = .thrissur

    init() {}

    init(reminder: MalayalamReminder) {
        id = reminder.id
        name = reminder.name
        kind = reminder.kind
        if let month = reminder.malayalamMonth {
            self.malayalamMonth = month
            if let day = reminder.malayalamDay {
                usesMalayalamDate = true
                self.malayalamDay = day
            } else {
                // Month set without a specific day = month restriction alongside nakshatra
                usesMalayalamMonth = true
            }
        }
        if let nakshatra = reminder.nakshatra {
            usesNakshatra = true
            self.nakshatra = nakshatra
        } else {
            usesNakshatra = false
        }
        hour = reminder.reminderTime.hour ?? 7
        minute = reminder.reminderTime.minute ?? 0
        advanceMinutes = reminder.advanceMinutes
        location = reminder.location
    }

    func makeReminder() -> MalayalamReminder {
        // Determine malayalamMonth from whichever flag is active
        let month: MalayalamMonth? = usesMalayalamDate ? malayalamMonth
                                   : usesMalayalamMonth ? malayalamMonth
                                   : nil
        return MalayalamReminder(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            malayalamMonth: month,
            malayalamDay: usesMalayalamDate ? malayalamDay : nil,
            nakshatra: usesNakshatra ? nakshatra : nil,
            reminderTime: DateComponents(hour: hour, minute: minute),
            advanceMinutes: advanceMinutes,
            location: location
        )
    }
}

@MainActor
@Observable
final class ReminderViewModel {
    var reminders: [MalayalamReminder] = []
    var draft = ReminderDraft()
    var selectedReminderID: MalayalamReminder.ID?
    var generatedEvents: [CalendarEvent] = []
    var generatedAlerts: [PanchangamAlert] = []
    var isLoading = false
    var errorMessage: String?

    // Duplicate nakshatra policy (synced from CalendarViewModel via RemindersView)
    var duplicateNakshatraPolicy: DuplicateNakshatraPolicy = .preferSecondUnlessShort
    var duplicateNakshatraThreshold: DuplicateNakshatraThreshold = .default

    // Occurrence analysis for the current draft's nakshatra+month combination
    var occurrenceAnalysis: NakshatraOccurrenceAnalysis?

    private let analyzer = NakshatraOccurrenceAnalyzer()
    private let generator: ReminderEventGenerating
    private let calendarService: CalendarIntegrating
    private let notificationService: NotificationScheduling
    private let reminderStore: ReminderStoring

    init(
        generator: ReminderEventGenerating = MalayalamReminderEventGenerator(),
        calendarService: CalendarIntegrating = EventKitCalendarService(),
        notificationService: NotificationScheduling = UserNotificationService(),
        reminderStore: ReminderStoring = FileReminderStore()
    ) {
        self.generator = generator
        self.calendarService = calendarService
        self.notificationService = notificationService
        self.reminderStore = reminderStore
    }

    var selectedReminder: MalayalamReminder? {
        guard let selectedReminderID else { return reminders.first }
        return reminders.first { $0.id == selectedReminderID }
    }

    var canSaveDraft: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (draft.usesMalayalamDate || draft.usesNakshatra)
    }

    func createReminder(location: GeoLocation) {
        draft = ReminderDraft()
        draft.location = location
        draft.name = "New Reminder"
        selectedReminderID = nil
        generatedEvents = []
        generatedAlerts = []
        errorMessage = nil
    }

    func edit(reminder: MalayalamReminder) {
        selectedReminderID = reminder.id
        draft = ReminderDraft(reminder: reminder)
        generatedEvents = []
        generatedAlerts = []
        errorMessage = nil
    }

    @discardableResult
    func saveDraft() -> MalayalamReminder? {
        guard canSaveDraft else {
            errorMessage = "Add a name and at least one matching rule."
            return nil
        }

        let reminder = draft.makeReminder()
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[index] = reminder
        } else {
            reminders.append(reminder)
        }
        selectedReminderID = reminder.id
        draft = ReminderDraft(reminder: reminder)
        errorMessage = nil
        persistReminders()
        return reminder
    }

    func deleteSelectedReminder() {
        guard let selectedReminderID else { return }
        reminders.removeAll { $0.id == selectedReminderID }
        self.selectedReminderID = reminders.first?.id
        if let reminder = reminders.first {
            draft = ReminderDraft(reminder: reminder)
        } else {
            draft = ReminderDraft()
        }
        generatedEvents = []
        generatedAlerts = []
        persistReminders()
    }

    func loadReminders() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let saved = try await reminderStore.loadReminders()
            if !saved.isEmpty {
                reminders = saved
            }
            selectedReminderID = reminders.first?.id
            if let reminder = reminders.first {
                draft = ReminderDraft(reminder: reminder)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func preview(reminder: MalayalamReminder, days: [PanchangamDay]) async {
        generatedEvents = await generator.events(for: reminder, in: days)
        generatedAlerts = await generator.alerts(for: reminder, in: days)
    }

    func export(reminder: MalayalamReminder, days: [PanchangamDay]) async {
        errorMessage = nil
        let events = await generator.events(for: reminder, in: days)
        do {
            try await calendarService.addEvents(events)
            generatedEvents = events
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scheduleAlerts(reminder: MalayalamReminder, days: [PanchangamDay]) async {
        errorMessage = nil
        let alerts = await generator.alerts(for: reminder, in: days)
        do {
            try await notificationService.requestAuthorization()
            for alert in alerts {
                try await notificationService.schedule(alert: alert)
            }
            generatedAlerts = alerts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Recompute occurrence analysis for the current draft whenever nakshatra/month
    /// settings or the policy changes. Pass in the full year `days` array.
    func refreshOccurrenceAnalysis(days: [PanchangamDay]) {
        guard draft.usesNakshatra && draft.usesMalayalamMonth else {
            occurrenceAnalysis = nil
            return
        }
        let nakshatra = draft.nakshatra
        let month = draft.malayalamMonth
        let policy = duplicateNakshatraPolicy
        let threshold = duplicateNakshatraThreshold
        occurrenceAnalysis = analyzer.analyze(
            nakshatra: nakshatra,
            month: month,
            in: days,
            policy: policy,
            threshold: threshold
        )
    }

    private func persistReminders() {
        let snapshot = reminders
        Task {
            do {
                try await reminderStore.saveReminders(snapshot)
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
