import Foundation

enum CalculationMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case keralaTraditional
    case sunriseNakshatra
    case majorityCivilDay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keralaTraditional: "Kerala Traditional"
        case .sunriseNakshatra: "Sunrise Nakshatra"
        case .majorityCivilDay: "Majority Civil Day"
        }
    }
}

enum LanguagePreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case english
    case malayalam
    case bilingual

    var id: String { rawValue }
}

enum AyanamsaSelection: String, CaseIterable, Codable, Identifiable, Sendable {
    case lahiri
    case raman
    case krishnamurti

    var id: String { rawValue }
}

enum ValidationStrictness: String, CaseIterable, Codable, Identifiable, Sendable {
    case relaxed
    case standard
    case strict

    var id: String { rawValue }
}

enum CalendarViewMode: String, CaseIterable, Identifiable, Sendable {
    case year, month, week, day

    var id: String { rawValue }

    var title: String {
        switch self {
        case .year: "Year"
        case .month: "Month"
        case .week: "Week"
        case .day: "Day"
        }
    }

    var systemImage: String {
        switch self {
        case .year: "square.grid.3x3"
        case .month: "calendar"
        case .week: "rectangle.split.3x1"
        case .day: "doc.text"
        }
    }
}

enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case calendar
    case reminders
    case family

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar:  "Calendar"
        case .reminders: "Reminders"
        case .family:    "Family"
        }
    }

    var systemImage: String {
        switch self {
        case .calendar:  "calendar"
        case .reminders: "bell"
        case .family:    "person.2.fill"
        }
    }
}

enum PanchangamError: Error, LocalizedError, Sendable {
    case invalidDate
    case calculationUnavailable(String)
    case calendarAccessDenied
    case notificationAccessDenied
    case geocodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDate:
            "The requested date could not be constructed."
        case .calculationUnavailable(let detail):
            "Panchangam calculation is unavailable: \(detail)"
        case .calendarAccessDenied:
            "Calendar access was denied."
        case .notificationAccessDenied:
            "Notification access was denied."
        case .geocodingFailed(let query):
            "No location could be found for \(query)."
        }
    }
}
