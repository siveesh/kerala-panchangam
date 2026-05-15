import Foundation

// MARK: - Policy

enum DuplicateNakshatraPolicy: String, CaseIterable, Codable, Identifiable, Sendable {
    case alwaysSecond
    case preferSecondUnlessShort
    case alwaysFirst
    case longestDuration
    case askEveryYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alwaysSecond:           "Always Second Occurrence"
        case .preferSecondUnlessShort: "Prefer Second (Unless Short)"
        case .alwaysFirst:            "Always First Occurrence"
        case .longestDuration:        "Longest Duration"
        case .askEveryYear:           "Ask Every Year"
        }
    }

    var explanation: String {
        switch self {
        case .alwaysSecond:
            "Always uses the second occurrence of the nakshatra in the month."
        case .preferSecondUnlessShort:
            "Uses the second occurrence unless its duration falls below the threshold, in which case the first is preferred. Recommended for birthdays and anniversaries."
        case .alwaysFirst:
            "Always uses the first occurrence of the nakshatra in the month."
        case .longestDuration:
            "Uses whichever occurrence has the longest duration."
        case .askEveryYear:
            "Displays all occurrences for review each time you generate events, so you can choose manually."
        }
    }
}

// MARK: - Threshold

struct DuplicateNakshatraThreshold: Codable, Equatable, Sendable {

    enum Kind: String, Codable, Sendable {
        case percentage   // fraction of a solar day (sunrise-to-sunrise)
        case fixedHours
    }

    var kind: Kind = .percentage
    var percentage: Double = 0.25  // 25 % of day duration
    var hours: Double = 6.0        // hours used when kind == .fixedHours

    static let `default` = DuplicateNakshatraThreshold()

    func isShort(duration: TimeInterval, dayDuration: TimeInterval) -> Bool {
        switch kind {
        case .percentage: duration < dayDuration * percentage
        case .fixedHours: duration < hours * 3_600
        }
    }

    var displayString: String {
        switch kind {
        case .percentage: "\(Int(percentage * 100))% of day"
        case .fixedHours: String(format: "%.1f hrs", hours)
        }
    }
}

// MARK: - Single occurrence

struct NakshatraOccurrence: Identifiable, Sendable {
    /// 1-based index within the month.
    let occurrenceNumber: Int
    /// All `PanchangamDay`s in this run where `mainNakshatra == nakshatra`.
    let days: [PanchangamDay]
    /// Aggregated duration from `nakshatraPeriods` for the target nakshatra.
    let totalDuration: TimeInterval
    /// Time the nakshatra first becomes active on the first day (nil = before sunrise).
    let transitionInTime: Date?
    /// Time the nakshatra ends on the last day (nil = continues past end of window).
    let transitionOutTime: Date?
    /// Whether the policy recommends this occurrence.
    var isRecommended: Bool = false
    /// Human-readable explanation of the recommendation or duration summary.
    var reasoning: String = ""

    var id: Int { occurrenceNumber }

    var durationHours: Double { totalDuration / 3_600 }

    var firstDay: PanchangamDay? { days.first }
    var lastDay: PanchangamDay? { days.last }

    /// True when the nakshatra is active at sunrise on the first day.
    var isSunriseNakshatra: Bool {
        guard let first = days.first else { return false }
        return first.sunriseNakshatra == first.mainNakshatra
    }

    var ordinalLabel: String {
        switch occurrenceNumber {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(occurrenceNumber)th"
        }
    }

    /// Formatted duration string, e.g. "14h 32m".
    var durationLabel: String {
        let h = Int(totalDuration / 3_600)
        let m = Int((totalDuration.truncatingRemainder(dividingBy: 3_600)) / 60)
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

// MARK: - Full analysis result

struct NakshatraOccurrenceAnalysis: Sendable {
    let nakshatra: Nakshatra
    let month: MalayalamMonth?
    let occurrences: [NakshatraOccurrence]
    let policy: DuplicateNakshatraPolicy
    let threshold: DuplicateNakshatraThreshold

    var isDuplicate: Bool { occurrences.count > 1 }
    var isEmpty: Bool { occurrences.isEmpty }

    var recommendedOccurrence: NakshatraOccurrence? {
        occurrences.first { $0.isRecommended }
    }

    /// Days belonging to the recommended (or sole) occurrence.
    var recommendedDays: [PanchangamDay] {
        recommendedOccurrence?.days ?? occurrences.first?.days ?? []
    }
}
