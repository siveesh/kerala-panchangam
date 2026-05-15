import Foundation

// MARK: - Paksha
// Typed enum — Tithi.paksha currently returns String; this is the typed equivalent
// used by BirthDetails and DeathDetails. Bridge via Paksha.from(_:Tithi).

enum Paksha: String, CaseIterable, Codable, Identifiable, Sendable {
    case shukla
    case krishna

    var id: String { rawValue }

    var englishName: String {
        switch self {
        case .shukla:  "Shukla Paksha"
        case .krishna: "Krishna Paksha"
        }
    }

    var malayalamName: String {
        switch self {
        case .shukla:  "ശുക്ലപക്ഷം"
        case .krishna: "കൃഷ്ണപക്ഷം"
        }
    }

    var shortName: String {
        switch self {
        case .shukla:  "Shukla"
        case .krishna: "Krishna"
        }
    }

    /// Derives paksha from Tithi rawValue (0–14 = Shukla, 15–29 = Krishna).
    static func from(_ tithi: Tithi) -> Paksha {
        tithi.rawValue < 15 ? .shukla : .krishna
    }
}

// MARK: - FieldEntryMode

/// How a Panchangam field value was obtained — drives the conflict resolution UI.
enum FieldEntryMode: String, Codable, Hashable, Sendable {
    case unset       // value not yet provided
    case calculated  // auto-derived from date + location
    case manual      // user typed it in directly
    case confirmed   // user reviewed and accepted the calculated value
    case overridden  // user disagreed; manual value takes precedence
}

// MARK: - Conflict types

enum ConflictableField: String, Sendable {
    case nakshatra
    case tithi
    case lagna
}

/// Emitted when a freshly calculated value differs from a user-entered value.
struct FieldConflict: Identifiable, Sendable {
    let id: UUID
    let field: ConflictableField
    let calculatedDescription: String
    let enteredDescription: String
}

// MARK: - BirthDetails

struct BirthDetails: Codable, Hashable, Sendable {
    var dateOfBirth: Date
    var birthTime: Date?              // nil = birth time unknown (used for astronomical calculations)
    /// Hour (0-23) exactly as the user typed it — timezone-independent display value.
    /// Populated whenever birthTime is set; nil for profiles saved before this field was added.
    var birthTimeDisplayHour: Int?
    /// Minute (0-59) exactly as the user typed it — timezone-independent display value.
    var birthTimeDisplayMinute: Int?
    var birthLocation: GeoLocation?   // nil = birth location unknown

    /// Formatted "h:mm AM/PM" string using the stored display hour/minute.
    /// Falls back to formatting `birthTime` in `TimeZone.current` for profiles
    /// that predate the explicit display-field storage.
    var displayedBirthTime: String? {
        if let h = birthTimeDisplayHour, let m = birthTimeDisplayMinute {
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            let ampm = h < 12 ? "AM" : "PM"
            return String(format: "%d:%02d %@", h12, m, ampm)
        }
        guard let time = birthTime else { return nil }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.timeZone  = TimeZone.current
        return fmt.string(from: time)
    }

    // Malayalam calendar values — auto-calculated when DOB + location are available
    var birthNakshatra: Nakshatra?
    var birthTithi: Tithi?
    var birthPaksha: Paksha?
    var birthMalayalamMonth: MalayalamMonth?
    var birthMalayalamDay: Int?
    var birthKollavarshamYear: Int?

    // Lagna (ascendant rasi) — only calculable when birth time AND location are known
    var lagna: Rasi?

    // Entry mode tracks whether each value is calculated or manually entered
    var nakshatraEntry: FieldEntryMode
    var tithiEntry: FieldEntryMode
    var lagnaEntry: FieldEntryMode

    init(
        dateOfBirth: Date = .now,
        birthTime: Date? = nil,
        birthTimeDisplayHour: Int? = nil,
        birthTimeDisplayMinute: Int? = nil,
        birthLocation: GeoLocation? = nil,
        birthNakshatra: Nakshatra? = nil,
        birthTithi: Tithi? = nil,
        birthPaksha: Paksha? = nil,
        birthMalayalamMonth: MalayalamMonth? = nil,
        birthMalayalamDay: Int? = nil,
        birthKollavarshamYear: Int? = nil,
        lagna: Rasi? = nil,
        nakshatraEntry: FieldEntryMode = .unset,
        tithiEntry: FieldEntryMode = .unset,
        lagnaEntry: FieldEntryMode = .unset
    ) {
        self.dateOfBirth = dateOfBirth
        self.birthTime = birthTime
        self.birthTimeDisplayHour = birthTimeDisplayHour
        self.birthTimeDisplayMinute = birthTimeDisplayMinute
        self.birthLocation = birthLocation
        self.birthNakshatra = birthNakshatra
        self.birthTithi = birthTithi
        self.birthPaksha = birthPaksha
        self.birthMalayalamMonth = birthMalayalamMonth
        self.birthMalayalamDay = birthMalayalamDay
        self.birthKollavarshamYear = birthKollavarshamYear
        self.lagna = lagna
        self.nakshatraEntry = nakshatraEntry
        self.tithiEntry = tithiEntry
        self.lagnaEntry = lagnaEntry
    }

    /// True when time-sensitive values (lagna) can be reliably calculated.
    var hasExactBirthTime: Bool { birthTime != nil && birthLocation != nil }
}

// MARK: - DeathDetails

struct DeathDetails: Codable, Hashable, Sendable {
    var dateOfDeath: Date
    var deathTime: Date?
    /// Hour (0-23) exactly as the user typed it — timezone-independent display value.
    var deathTimeDisplayHour: Int?
    /// Minute (0-59) exactly as the user typed it — timezone-independent display value.
    var deathTimeDisplayMinute: Int?
    var deathLocation: GeoLocation?

    /// Formatted "h:mm AM/PM" using stored display hour/minute, or fallback to TimeZone.current.
    var displayedDeathTime: String? {
        if let h = deathTimeDisplayHour, let m = deathTimeDisplayMinute {
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            let ampm = h < 12 ? "AM" : "PM"
            return String(format: "%d:%02d %@", h12, m, ampm)
        }
        guard let time = deathTime else { return nil }
        let fmt = DateFormatter()
        fmt.timeStyle = .short
        fmt.timeZone  = TimeZone.current
        return fmt.string(from: time)
    }

    var deathNakshatra: Nakshatra?
    var deathTithi: Tithi?
    var deathPaksha: Paksha?
    var deathMalayalamMonth: MalayalamMonth?
    var deathMalayalamDay: Int?
    var deathKollavarshamYear: Int?

    var nakshatraEntry: FieldEntryMode
    var tithiEntry: FieldEntryMode

    init(
        dateOfDeath: Date = .now,
        deathTime: Date? = nil,
        deathTimeDisplayHour: Int? = nil,
        deathTimeDisplayMinute: Int? = nil,
        deathLocation: GeoLocation? = nil,
        deathNakshatra: Nakshatra? = nil,
        deathTithi: Tithi? = nil,
        deathPaksha: Paksha? = nil,
        deathMalayalamMonth: MalayalamMonth? = nil,
        deathMalayalamDay: Int? = nil,
        deathKollavarshamYear: Int? = nil,
        nakshatraEntry: FieldEntryMode = .unset,
        tithiEntry: FieldEntryMode = .unset
    ) {
        self.dateOfDeath = dateOfDeath
        self.deathTime = deathTime
        self.deathTimeDisplayHour = deathTimeDisplayHour
        self.deathTimeDisplayMinute = deathTimeDisplayMinute
        self.deathLocation = deathLocation
        self.deathNakshatra = deathNakshatra
        self.deathTithi = deathTithi
        self.deathPaksha = deathPaksha
        self.deathMalayalamMonth = deathMalayalamMonth
        self.deathMalayalamDay = deathMalayalamDay
        self.deathKollavarshamYear = deathKollavarshamYear
        self.nakshatraEntry = nakshatraEntry
        self.tithiEntry = tithiEntry
    }
}

// MARK: - GrahanilaMode

enum GrahanilaMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case notSet          // chart not yet generated or entered
    case calculated      // auto-calculated from birth/death date + location
    case manual          // entirely user-entered
    case manualOverride  // started as calculated, user edited individual cells

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notSet:         "Not Set"
        case .calculated:     "Calculated"
        case .manual:         "Manual Entry"
        case .manualOverride: "Manual Override"
        }
    }

    var systemImage: String {
        switch self {
        case .notSet:         "moon.stars"
        case .calculated:     "sparkles"
        case .manual:         "hand.point.up.left"
        case .manualOverride: "pencil.and.sparkles"
        }
    }
}

// MARK: - RasiPlacement
// Distinct from RasiHouse (which carries [PlanetPosition] with full longitude data).
// RasiPlacement is the storable, manual-entry model — no longitudes required.

struct RasiPlacement: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let planet: Planet
    let rasi: Rasi
    var isRetrograde: Bool

    init(id: UUID = UUID(), planet: Planet, rasi: Rasi, isRetrograde: Bool = false) {
        self.id = id
        self.planet = planet
        self.rasi = rasi
        self.isRetrograde = isRetrograde
    }
}

// MARK: - PersonGrahanila

struct PersonGrahanila: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var mode: GrahanilaMode
    /// Placements derived from PlanetaryCalculator (may be empty if not yet calculated).
    var calculatedPlacements: [RasiPlacement]
    /// User-entered placements (set when mode is .manual or .manualOverride).
    var manualPlacements: [RasiPlacement]
    var lagna: Rasi?
    var ayanamsa: AyanamsaSelection?
    /// ISO date string of the date used for calculation (birth/death date).
    var calculationDateKey: String?
    /// True when calculated without an exact time (birth/death time unknown).
    var isEstimated: Bool

    init(
        id: UUID = UUID(),
        mode: GrahanilaMode = .notSet,
        calculatedPlacements: [RasiPlacement] = [],
        manualPlacements: [RasiPlacement] = [],
        lagna: Rasi? = nil,
        ayanamsa: AyanamsaSelection? = nil,
        calculationDateKey: String? = nil,
        isEstimated: Bool = false
    ) {
        self.id = id
        self.mode = mode
        self.calculatedPlacements = calculatedPlacements
        self.manualPlacements = manualPlacements
        self.lagna = lagna
        self.ayanamsa = ayanamsa
        self.calculationDateKey = calculationDateKey
        self.isEstimated = isEstimated
    }

    // Custom Decodable to handle JSON saved before isEstimated / calculationDateKey were added.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(UUID.self,            forKey: .id)
        mode                 = try c.decode(GrahanilaMode.self,   forKey: .mode)
        calculatedPlacements = try c.decodeIfPresent([RasiPlacement].self, forKey: .calculatedPlacements) ?? []
        manualPlacements     = try c.decodeIfPresent([RasiPlacement].self, forKey: .manualPlacements)     ?? []
        lagna                = try c.decodeIfPresent(Rasi.self,            forKey: .lagna)
        ayanamsa             = try c.decodeIfPresent(AyanamsaSelection.self, forKey: .ayanamsa)
        calculationDateKey   = try c.decodeIfPresent(String.self,          forKey: .calculationDateKey)
        isEstimated          = try c.decodeIfPresent(Bool.self,            forKey: .isEstimated) ?? false
    }

    /// Placements used for display, based on the active mode.
    var activePlacements: [RasiPlacement] {
        switch mode {
        case .notSet:          return []
        case .calculated:      return calculatedPlacements
        case .manual:          return manualPlacements
        case .manualOverride:  return manualPlacements
        }
    }

    /// Active planets in a specific rasi.
    func placements(in rasi: Rasi) -> [RasiPlacement] {
        activePlacements.filter { $0.rasi == rasi }
    }

    var isEmpty: Bool { mode == .notSet }

    static let empty = PersonGrahanila()
}

// MARK: - ShraddhamObservanceMode

/// Global setting that controls how the annual Śrāddham date is determined.
/// Kerala traditional practice uses the death nakshatra day; North Indian
/// practice uses the tithi. This enum lets the user choose.
enum ShraddhamObservanceMode: String, CaseIterable, Codable, Identifiable, Sendable {
    /// Kerala traditional: observe on the day the death nakshatra falls
    /// in the same Malayalam month each year. No tithi fallback.
    case nakshatraOnly
    /// Nakshatra first; falls back to tithi if nakshatra is not set.
    case nakshatraPreferred
    /// Tithi first; falls back to nakshatra if tithi is not set.
    case tithiPreferred
    /// Generate two reminders each year — one for the tithi day and
    /// one for the nakshatra day (useful when both traditions are followed).
    case tithiAndNakshatra

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nakshatraOnly:      "Nakshatra Only"
        case .nakshatraPreferred: "Nakshatra Preferred"
        case .tithiPreferred:     "Tithi Preferred"
        case .tithiAndNakshatra:  "Tithi + Nakshatra"
        }
    }

    var explanation: String {
        switch self {
        case .nakshatraOnly:
            "Observe Śrāddham on the day the death nakshatra falls in the same Malayalam month. Kerala traditional practice."
        case .nakshatraPreferred:
            "Use nakshatra when available; fall back to tithi if the death nakshatra is not set."
        case .tithiPreferred:
            "Use tithi (sunrise rule) when available; fall back to nakshatra if the death tithi is not set."
        case .tithiAndNakshatra:
            "Schedule two reminders per year — one for the tithi-matching day and one for the nakshatra day."
        }
    }
}

// MARK: - FamilyReminderPreferences

struct FamilyReminderPreferences: Codable, Hashable, Sendable {
    var enableBirthdayReminder: Bool
    var birthdayReminderAdvanceMinutes: Int
    var birthdayReminderTime: DateComponents
    /// Per-person duplicate-nakshatra policy for birthday star calculation.
    var birthdayNakshatraPolicy: DuplicateNakshatraPolicy

    var enableShraddhamReminder: Bool
    var shraddhamReminderAdvanceMinutes: Int
    var shraddhamReminderTime: DateComponents

    init(
        enableBirthdayReminder: Bool = true,
        birthdayReminderAdvanceMinutes: Int = 15,
        birthdayReminderTime: DateComponents = DateComponents(hour: 7, minute: 0),
        birthdayNakshatraPolicy: DuplicateNakshatraPolicy = .preferSecondUnlessShort,
        enableShraddhamReminder: Bool = true,
        shraddhamReminderAdvanceMinutes: Int = 15,
        shraddhamReminderTime: DateComponents = DateComponents(hour: 7, minute: 0)
    ) {
        self.enableBirthdayReminder = enableBirthdayReminder
        self.birthdayReminderAdvanceMinutes = birthdayReminderAdvanceMinutes
        self.birthdayReminderTime = birthdayReminderTime
        self.birthdayNakshatraPolicy = birthdayNakshatraPolicy
        self.enableShraddhamReminder = enableShraddhamReminder
        self.shraddhamReminderAdvanceMinutes = shraddhamReminderAdvanceMinutes
        self.shraddhamReminderTime = shraddhamReminderTime
    }

    static let `default` = FamilyReminderPreferences()
}

// MARK: - PersonProfile

struct PersonProfile: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var fullName: String
    var nickname: String
    var relationshipTag: String           // "Father", "Spouse", "Grandmother", etc.
    var notes: String

    // Optional additional personal info — shown in exported PDF
    var fatherName: String
    var motherName: String
    var mobileNumber: String
    var address: String

    var birthDetails: BirthDetails?
    var deathDetails: DeathDetails?       // nil = living

    var birthGrahanila: PersonGrahanila
    var deathGrahanila: PersonGrahanila   // .empty for living persons

    var reminderPreferences: FamilyReminderPreferences
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fullName: String = "",
        nickname: String = "",
        relationshipTag: String = "",
        notes: String = "",
        fatherName: String = "",
        motherName: String = "",
        mobileNumber: String = "",
        address: String = "",
        birthDetails: BirthDetails? = nil,
        deathDetails: DeathDetails? = nil,
        birthGrahanila: PersonGrahanila = .empty,
        deathGrahanila: PersonGrahanila = .empty,
        reminderPreferences: FamilyReminderPreferences = .default,
        isArchived: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fullName = fullName
        self.nickname = nickname
        self.relationshipTag = relationshipTag
        self.notes = notes
        self.fatherName = fatherName
        self.motherName = motherName
        self.mobileNumber = mobileNumber
        self.address = address
        self.birthDetails = birthDetails
        self.deathDetails = deathDetails
        self.birthGrahanila = birthGrahanila
        self.deathGrahanila = deathGrahanila
        self.reminderPreferences = reminderPreferences
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    // Custom Decodable so existing JSON (without fatherName/motherName/mobileNumber/address)
    // still loads cleanly — missing keys default to "".
    private enum CodingKeys: String, CodingKey {
        case id, fullName, nickname, relationshipTag, notes
        case fatherName, motherName, mobileNumber, address
        case birthDetails, deathDetails
        case birthGrahanila, deathGrahanila
        case reminderPreferences, isArchived, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try  c.decode(UUID.self,   forKey: .id)
        fullName            = try  c.decode(String.self, forKey: .fullName)
        nickname            = try  c.decode(String.self, forKey: .nickname)
        relationshipTag     = try  c.decode(String.self, forKey: .relationshipTag)
        notes               = try  c.decode(String.self, forKey: .notes)
        fatherName          = try  c.decodeIfPresent(String.self, forKey: .fatherName)    ?? ""
        motherName          = try  c.decodeIfPresent(String.self, forKey: .motherName)    ?? ""
        mobileNumber        = try  c.decodeIfPresent(String.self, forKey: .mobileNumber)  ?? ""
        address             = try  c.decodeIfPresent(String.self, forKey: .address)       ?? ""
        birthDetails        = try  c.decodeIfPresent(BirthDetails.self,    forKey: .birthDetails)
        deathDetails        = try  c.decodeIfPresent(DeathDetails.self,    forKey: .deathDetails)
        birthGrahanila      = try  c.decode(PersonGrahanila.self,          forKey: .birthGrahanila)
        deathGrahanila      = try  c.decode(PersonGrahanila.self,          forKey: .deathGrahanila)
        reminderPreferences = try  c.decode(FamilyReminderPreferences.self, forKey: .reminderPreferences)
        isArchived          = try  c.decode(Bool.self,   forKey: .isArchived)
        createdAt           = try  c.decode(Date.self,   forKey: .createdAt)
        updatedAt           = try  c.decode(Date.self,   forKey: .updatedAt)
    }

    var isDeceased: Bool { deathDetails != nil }
    var displayName: String { nickname.isEmpty ? fullName : nickname }
    var hasAnyBirthData: Bool { birthDetails != nil }
}

// MARK: - NakshatraHighlight
// Used by calendar views to colour day cells based on saved family data.

struct NakshatraHighlight: Sendable {
    enum Kind: Sendable {
        case birthday   // green
        case deathDay   // amber
    }

    let nakshatra: Nakshatra
    let kind: Kind
    let personName: String
    let personID: UUID
}

// MARK: - FamilyDayEvent
// A lightweight summary of a specific upcoming family event on a calendar date.
// Drives the yellow-text overlay in month/week cells and the event list in day view.

struct FamilyDayEvent: Identifiable, Sendable {
    let id: UUID
    /// Short name displayed in month/week cells (e.g. "★ Daughter" or "† Father").
    let label: String
    /// Full title for the day-view event list (e.g. "Daughter Star Birthday").
    let title: String
    let kind: NakshatraHighlight.Kind   // .birthday or .deathDay
}

// MARK: - ShraddhamDate

struct ShraddhamDate: Identifiable, Sendable {
    let id: UUID
    let personID: UUID
    let personName: String
    let gregorianDate: Date
    let tithi: Tithi
    let paksha: Paksha
    /// Human-readable label e.g. "Karkidakam 14 · 1201".
    let malayalamDateLabel: String
    /// Description of which rule was used to pick this day.
    let selectionRuleDescription: String

    init(
        id: UUID = UUID(),
        personID: UUID,
        personName: String,
        gregorianDate: Date,
        tithi: Tithi,
        paksha: Paksha,
        malayalamDateLabel: String,
        selectionRuleDescription: String
    ) {
        self.id = id
        self.personID = personID
        self.personName = personName
        self.gregorianDate = gregorianDate
        self.tithi = tithi
        self.paksha = paksha
        self.malayalamDateLabel = malayalamDateLabel
        self.selectionRuleDescription = selectionRuleDescription
    }
}
