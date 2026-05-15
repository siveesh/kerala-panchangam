import Foundation

// MARK: - FamilyStoring

protocol FamilyStoring: Sendable {
    func loadProfiles() async throws -> [PersonProfile]
    func saveProfiles(_ profiles: [PersonProfile]) async throws
}

// MARK: - FamilyEventGenerating

protocol FamilyEventGenerating: Sendable {
    func birthdayEvents(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        policy: DuplicateNakshatraPolicy,
        threshold: DuplicateNakshatraThreshold
    ) async -> [CalendarEvent]

    func shraddhamEvents(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        mode: ShraddhamObservanceMode
    ) async -> [CalendarEvent]

    func birthdayAlerts(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        policy: DuplicateNakshatraPolicy,
        threshold: DuplicateNakshatraThreshold
    ) async -> [PanchangamAlert]

    func shraddhamAlerts(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        mode: ShraddhamObservanceMode
    ) async -> [PanchangamAlert]
}

// MARK: - TithiSelectionRule
// Pluggable strategy for choosing the canonical Śrāddham observance day.
// Phase 1 ships SunriseTithiSelectionRule.
// Aparahna-based logic can be added as a new conformance without changing call sites.

protocol TithiSelectionRule: Sendable {
    /// Human-readable name shown in the UI.
    var displayName: String { get }

    /// Given an array of PanchangamDays whose tithi matches the required tithi,
    /// return the canonical observance day (or nil if none is suitable).
    func selectDay(from candidates: [PanchangamDay], tithi: Tithi) -> PanchangamDay?
}

// MARK: - SunriseTithiSelectionRule
// Phase-1 implementation: pick the first day where the required tithi
// prevails at sunrise (i.e. PanchangamDay.tithi == deathTithi).

struct SunriseTithiSelectionRule: TithiSelectionRule {
    var displayName: String { "Tithi at Sunrise (standard)" }

    func selectDay(from candidates: [PanchangamDay], tithi: Tithi) -> PanchangamDay? {
        candidates.first { $0.tithi == tithi }
    }
}

// Future conformance placeholder:
// struct AparahnaTithiSelectionRule: TithiSelectionRule {
//     // Selects the day where the tithi prevails during the Aparahna (afternoon) period.
// }
