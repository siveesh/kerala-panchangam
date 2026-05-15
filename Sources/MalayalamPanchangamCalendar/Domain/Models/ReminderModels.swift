import Foundation

enum ReminderKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case starBased
    case malayalamDate
    case birthday
    case deathAnniversary
    case panchangamAlert
    case templeFestival

    var id: String { rawValue }

    var title: String {
        switch self {
        case .starBased: "Star"
        case .malayalamDate: "Malayalam Date"
        case .birthday: "Birthday"
        case .deathAnniversary: "Death Anniversary"
        case .panchangamAlert: "Panchangam Alert"
        case .templeFestival: "Temple/Festival"
        }
    }
}

struct MalayalamReminder: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var kind: ReminderKind
    var malayalamMonth: MalayalamMonth?
    var malayalamDay: Int?
    var nakshatra: Nakshatra?
    var tithi: String?
    var reminderTime: DateComponents
    var advanceMinutes: Int
    var location: GeoLocation

    init(
        id: UUID = UUID(),
        name: String,
        kind: ReminderKind,
        malayalamMonth: MalayalamMonth? = nil,
        malayalamDay: Int? = nil,
        nakshatra: Nakshatra? = nil,
        tithi: String? = nil,
        reminderTime: DateComponents,
        advanceMinutes: Int,
        location: GeoLocation
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.malayalamMonth = malayalamMonth
        self.malayalamDay = malayalamDay
        self.nakshatra = nakshatra
        self.tithi = tithi
        self.reminderTime = reminderTime
        self.advanceMinutes = advanceMinutes
        self.location = location
    }
}

struct PanchangamAlert: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var fireDate: Date
    var isSilent: Bool

    init(id: UUID = UUID(), title: String, body: String, fireDate: Date, isSilent: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.isSilent = isSilent
    }
}

struct Festival: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var malayalamMonth: MalayalamMonth?
    var malayalamDay: Int?
    var nakshatra: Nakshatra?
    var notes: String

    init(id: UUID = UUID(), name: String, malayalamMonth: MalayalamMonth? = nil, malayalamDay: Int? = nil, nakshatra: Nakshatra? = nil, notes: String = "") {
        self.id = id
        self.name = name
        self.malayalamMonth = malayalamMonth
        self.malayalamDay = malayalamDay
        self.nakshatra = nakshatra
        self.notes = notes
    }
}

struct CalendarEvent: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var sourceReminderID: UUID?

    init(id: UUID = UUID(), title: String, startDate: Date, endDate: Date, notes: String = "", sourceReminderID: UUID? = nil) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.sourceReminderID = sourceReminderID
    }
}
