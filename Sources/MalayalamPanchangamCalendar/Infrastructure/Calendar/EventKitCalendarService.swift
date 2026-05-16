import EventKit
import Foundation

actor EventKitCalendarService: CalendarIntegrating {
    private let eventStore = EKEventStore()
    private let calendarTitle = "Malayalam Panchangam"

    func requestAccess() async throws {
        let granted = try await eventStore.requestFullAccessToEvents()
        if !granted {
            throw PanchangamError.calendarAccessDenied
        }
    }

    func createDedicatedCalendarIfNeeded() async throws -> String {
        if let existing = eventStore.calendars(for: .event).first(where: { $0.title == calendarTitle }) {
            return existing.calendarIdentifier
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = calendarTitle
        calendar.cgColor = CGColor(red: 0.15, green: 0.38, blue: 0.31, alpha: 1)
        calendar.source = eventStore.defaultCalendarForNewEvents?.source ?? eventStore.sources.first
        try eventStore.saveCalendar(calendar, commit: true)
        return calendar.calendarIdentifier
    }

    func addEvents(_ events: [CalendarEvent]) async throws {
        try await requestAccess()
        let calendarID = try await createDedicatedCalendarIfNeeded()
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else {
            throw PanchangamError.calculationUnavailable("Dedicated calendar could not be loaded.")
        }

        var added = 0
        var skipped = 0

        for event in events {
            // Deduplicate: search a ±1 day window around the event's start date and skip
            // if an event with the same title already exists on the same calendar day.
            // This prevents duplicates when the user presses "Add to Apple Calendar" more
            // than once (e.g. after adding a new profile).
            let windowStart = event.startDate.addingTimeInterval(-86_400)
            let windowEnd   = event.startDate.addingTimeInterval( 86_400)
            let predicate   = eventStore.predicateForEvents(
                withStart: windowStart, end: windowEnd, calendars: [calendar])
            let existing    = eventStore.events(matching: predicate)

            let gregorianCal = Calendar(identifier: .gregorian)
            let isDuplicate = existing.contains { ex in
                ex.title == event.title &&
                gregorianCal.isDate(ex.startDate, inSameDayAs: event.startDate)
            }

            if isDuplicate {
                skipped += 1
                continue
            }

            let ekEvent = EKEvent(eventStore: eventStore)
            ekEvent.calendar  = calendar
            ekEvent.title     = event.title
            ekEvent.startDate = event.startDate
            ekEvent.endDate   = event.endDate
            ekEvent.notes     = event.notes
            try eventStore.save(ekEvent, span: .thisEvent, commit: false)
            added += 1
        }

        try eventStore.commit()
    }
}
