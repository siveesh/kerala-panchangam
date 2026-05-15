import Foundation
import Observation

// MARK: - FamilyViewModel

/// Orchestrates the Family Profile feature: loading/saving PersonProfiles,
/// calculating Panchangam values for birth and death dates, generating
/// CalendarEvents and PanchangamAlerts per profile, and building the
/// calendar highlight sets used by month/week/year views.
///
/// Syncs `days`, `duplicateNakshatraPolicy`, `duplicateNakshatraThreshold`,
/// and `ayanamsaSelection` from CalendarViewModel via ContentView.
@MainActor
@Observable
final class FamilyViewModel {

    // MARK: - Published state

    var profiles: [PersonProfile] = []
    var selectedProfileID: UUID?

    /// The profile being created or edited.
    var draft = PersonProfile()
    var isDraftNew = false

    /// Conflicts detected when calculated values differ from manually entered values.
    var pendingConflicts: [FieldConflict] = []

    var isLoading = false
    var errorMessage: String?

    // MARK: - Synced from CalendarViewModel

    var days: [PanchangamDay] = []
    var duplicateNakshatraPolicy: DuplicateNakshatraPolicy = .preferSecondUnlessShort
    var duplicateNakshatraThreshold: DuplicateNakshatraThreshold = .default
    var ayanamsaSelection: AyanamsaSelection = .lahiri
    /// Synced from CalendarViewModel — controls how Śrāddham dates are determined.
    var shraddhamObservanceMode: ShraddhamObservanceMode = .nakshatraOnly

    // MARK: - Calendar overlay data

    /// Highlights passed to month/week/year views for green (birthday) dots.
    var birthHighlights: [NakshatraHighlight] = []
    /// Highlights passed to month/week/year views for amber (death day) dots.
    var deathHighlights: [NakshatraHighlight] = []
    /// Annual Śrāddham dates across all deceased profiles in the loaded `days`.
    var shraddhamDates: [ShraddhamDate] = []

    /// Events generated for the current draft (used in the preview sheet).
    var previewBirthdayEvents: [CalendarEvent] = []
    var previewShraddhamEvents: [CalendarEvent] = []

    /// Date-keyed map of upcoming family events across all active profiles.
    /// Key: "YYYY-MM-DD" in the primary location's timezone.
    /// Used by month/week cells (yellow label) and day view (event list).
    private(set) var familyEventsByDate: [String: [FamilyDayEvent]] = [:]

    // MARK: - Services (private)

    private let store: any FamilyStoring
    private let reminderStore: any ReminderStoring
    private let grahanilaService = PersonalGrahanilaService()
    private let eventGenerator = FamilyEventGenerator()
    private let calendarService = EventKitCalendarService()
    private let notificationService = UserNotificationService()
    private let panchangamCalculator = DefaultPanchangamCalculator()
    private let shraddhamFinder = ShraddhamDateFinder()

    // MARK: - Initialisation

    init(store: any FamilyStoring = FamilyStore(),
         reminderStore: any ReminderStoring = FileReminderStore()) {
        self.store = store
        self.reminderStore = reminderStore
    }

    // MARK: - Profile Management

    func loadProfiles() async {
        isLoading = true
        defer { isLoading = false }
        do {
            profiles = try await store.loadProfiles()
            refreshHighlights()
        } catch {
            errorMessage = "Failed to load profiles: \(error.localizedDescription)"
        }
    }

    func startNewProfile() {
        draft = PersonProfile()
        isDraftNew = true
        pendingConflicts = []
    }

    func edit(profile: PersonProfile) {
        draft = profile
        isDraftNew = false
        pendingConflicts = []
    }

    func saveDraft() async {
        draft.updatedAt = .now
        let savedID = draft.id
        if isDraftNew {
            profiles.append(draft)
        } else {
            if let idx = profiles.firstIndex(where: { $0.id == draft.id }) {
                profiles[idx] = draft
            } else {
                profiles.append(draft)
            }
        }
        isDraftNew = false
        selectedProfileID = savedID   // auto-select after save
        await persistProfiles()
        refreshHighlights()
    }

    func deleteProfile(_ profile: PersonProfile) async {
        profiles.removeAll { $0.id == profile.id }
        if selectedProfileID == profile.id {
            selectedProfileID = nil
        }
        await persistProfiles()
        refreshHighlights()
    }

    func deleteSelected() async {
        guard let id = selectedProfileID else { return }
        profiles.removeAll { $0.id == id }
        selectedProfileID = nil
        await persistProfiles()
        refreshHighlights()
    }

    func toggleArchive(profile: PersonProfile) async {
        if let idx = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[idx].isArchived.toggle()
            profiles[idx].updatedAt = .now
        }
        await persistProfiles()
    }

    // MARK: - Panchangam Calculation for Draft

    /// Calculates Panchangam values (nakshatra, tithi, Malayalam date) for the
    /// draft's birth and death dates. Populates `pendingConflicts` when a freshly
    /// calculated value differs from an existing manually entered value.
    ///
    /// Updates `draft.birthDetails` and `draft.deathDetails` with calculated
    /// values and sets their `FieldEntryMode` to `.calculated`.
    func recalculateDraft() async {
        pendingConflicts = []
        isLoading = true
        defer { isLoading = false }

        // --- Birth ---
        if let birth = draft.birthDetails, let loc = birth.birthLocation {
            await calculateBirthPanchangam(birth: birth, location: loc)
        }

        // --- Death ---
        if let death = draft.deathDetails, let loc = death.deathLocation {
            await calculateDeathPanchangam(death: death, location: loc)
        }
    }

    private func calculateBirthPanchangam(birth: BirthDetails, location: GeoLocation) async {
        do {
            let day = try await panchangamCalculator.calculateDay(
                date: birth.dateOfBirth,
                location: location,
                mode: .keralaTraditional
            )

            // ── Nakshatra: use exact birth time when known ─────────────────────
            // Janma Nakshatra is the nakshatra the Moon occupies at the moment of
            // birth, not at sunrise. Only fall back to day.mainNakshatra when the
            // birth time is unknown.
            //
            // IMPORTANT: `birth.birthTime` is a SwiftUI DatePicker value whose
            // DATE component may be today (the day the user opened the form), not
            // the actual birth date. We always extract only the hour/minute from
            // birthTime and combine them with the correct date from dateOfBirth.
            let calculatedNakshatra: Nakshatra
            if let birthTime = birth.birthTime {
                // combineDisplayedTime recovers the hour/minute the user *typed* on their
                // Mac (in TimeZone.current) and places them on the birth date in IST,
                // so a user whose Mac is set to a non-IST timezone still gets the correct
                // UTC moment (e.g. Mac=Qatar, user types "1:32 PM" meaning 1:32 PM IST).
                let exactMoment = Self.combineDisplayedTime(date: birth.dateOfBirth,
                                                            displayedTime: birthTime,
                                                            locationTimeZone: location.timeZone)
                let jd       = PlanetaryCalculator.julianDay(from: exactMoment)
                let tropical = PlanetaryCalculator().tropicalGeocentricLongitude(of: .moon, julianDay: jd)
                let ayanamsa = ApproximateAstronomyEngine().lahiriAyanamsa(on: exactMoment)
                let sidereal = (tropical - ayanamsa).normalizedDegrees
                calculatedNakshatra = Nakshatra.from(siderealLongitude: sidereal)
            } else {
                calculatedNakshatra = day.mainNakshatra
            }

            // Detect conflicts with existing manual entries
            if birth.nakshatraEntry == .manual || birth.nakshatraEntry == .overridden,
               let entered = birth.birthNakshatra, entered != calculatedNakshatra {
                pendingConflicts.append(FieldConflict(
                    id: UUID(), field: .nakshatra,
                    calculatedDescription: "\(calculatedNakshatra.englishName) (\(calculatedNakshatra.malayalamName))",
                    enteredDescription: "\(entered.englishName) (\(entered.malayalamName))"
                ))
            }
            if birth.tithiEntry == .manual || birth.tithiEntry == .overridden,
               let entered = birth.birthTithi, entered != day.tithi {
                let calcPaksha = Paksha.from(day.tithi)
                pendingConflicts.append(FieldConflict(
                    id: UUID(), field: .tithi,
                    calculatedDescription: "\(calcPaksha.shortName) \(day.tithi.englishName)",
                    enteredDescription: "\(Paksha.from(entered).shortName) \(entered.englishName)"
                ))
            }

            // Apply calculated values (only when not overridden by user)
            if birth.nakshatraEntry != .overridden {
                draft.birthDetails?.birthNakshatra = calculatedNakshatra
                draft.birthDetails?.nakshatraEntry = .calculated
            }
            if birth.tithiEntry != .overridden {
                draft.birthDetails?.birthTithi = day.tithi
                draft.birthDetails?.birthPaksha = Paksha.from(day.tithi)
                draft.birthDetails?.tithiEntry = .calculated
            }
            draft.birthDetails?.birthMalayalamMonth = day.malayalamMonth
            draft.birthDetails?.birthMalayalamDay = day.malayalamDay
            draft.birthDetails?.birthKollavarshamYear = day.kollavarshamYear

        } catch {
            errorMessage = "Birth date calculation failed: \(error.localizedDescription)"
        }
    }

    private func calculateDeathPanchangam(death: DeathDetails, location: GeoLocation) async {
        do {
            let day = try await panchangamCalculator.calculateDay(
                date: death.dateOfDeath,
                location: location,
                mode: .keralaTraditional
            )

            // Use exact death time for Nakshatra when known (same logic as birth).
            // Extract only hour/minute from deathTime and combine with dateOfDeath
            // to prevent a wrong base-date in the DatePicker from corrupting the JD.
            let calculatedNakshatra: Nakshatra
            if let deathTime = death.deathTime {
                let exactMoment = Self.combineDisplayedTime(date: death.dateOfDeath,
                                                            displayedTime: deathTime,
                                                            locationTimeZone: location.timeZone)
                let jd       = PlanetaryCalculator.julianDay(from: exactMoment)
                let tropical = PlanetaryCalculator().tropicalGeocentricLongitude(of: .moon, julianDay: jd)
                let ayanamsa = ApproximateAstronomyEngine().lahiriAyanamsa(on: exactMoment)
                let sidereal = (tropical - ayanamsa).normalizedDegrees
                calculatedNakshatra = Nakshatra.from(siderealLongitude: sidereal)
            } else {
                calculatedNakshatra = day.mainNakshatra
            }

            if death.nakshatraEntry == .manual || death.nakshatraEntry == .overridden,
               let entered = death.deathNakshatra, entered != calculatedNakshatra {
                pendingConflicts.append(FieldConflict(
                    id: UUID(), field: .nakshatra,
                    calculatedDescription: "\(calculatedNakshatra.englishName) (\(calculatedNakshatra.malayalamName))",
                    enteredDescription: "\(entered.englishName) (\(entered.malayalamName))"
                ))
            }
            if death.tithiEntry == .manual || death.tithiEntry == .overridden,
               let entered = death.deathTithi, entered != day.tithi {
                let calcPaksha = Paksha.from(day.tithi)
                pendingConflicts.append(FieldConflict(
                    id: UUID(), field: .tithi,
                    calculatedDescription: "\(calcPaksha.shortName) \(day.tithi.englishName)",
                    enteredDescription: "\(Paksha.from(entered).shortName) \(entered.englishName)"
                ))
            }

            if death.nakshatraEntry != .overridden {
                draft.deathDetails?.deathNakshatra = calculatedNakshatra
                draft.deathDetails?.nakshatraEntry = .calculated
            }
            if death.tithiEntry != .overridden {
                draft.deathDetails?.deathTithi = day.tithi
                draft.deathDetails?.deathPaksha = Paksha.from(day.tithi)
                draft.deathDetails?.tithiEntry = .calculated
            }
            draft.deathDetails?.deathMalayalamMonth = day.malayalamMonth
            draft.deathDetails?.deathMalayalamDay = day.malayalamDay
            draft.deathDetails?.deathKollavarshamYear = day.kollavarshamYear

        } catch {
            errorMessage = "Death date calculation failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Conflict Resolution

    /// Accept or reject a single field conflict.
    /// `acceptCalculated = true` → keep the calculated value (entry mode → .calculated).
    /// `acceptCalculated = false` → keep the user's manual value (entry mode → .overridden).
    func resolveConflict(_ conflict: FieldConflict, acceptCalculated: Bool) {
        pendingConflicts.removeAll { $0.id == conflict.id }

        guard !acceptCalculated else { return }   // calculated value already applied in recalculate

        // Restore the manually entered value and mark as overridden
        switch conflict.field {
        case .nakshatra:
            draft.birthDetails?.nakshatraEntry = .overridden
        case .tithi:
            draft.birthDetails?.tithiEntry = .overridden
        case .lagna:
            draft.birthDetails?.lagnaEntry = .overridden
        }
    }

    // MARK: - Grahanila Calculation

    /// (Re)calculate the birth and death Grahanila charts for the current draft.
    func recalculateGrahanila() async {
        isLoading = true
        defer { isLoading = false }

        // Birth Grahanila
        if let birth = draft.birthDetails {
            let loc = birth.birthLocation ?? .thrissur
            if let grahanila = grahanilaService.calculate(
                date: birth.dateOfBirth,
                time: birth.birthTime,
                location: loc,
                ayanamsa: ayanamsaSelection
            ) {
                var updated = grahanila
                // Preserve manual overrides
                if draft.birthGrahanila.mode == .manualOverride {
                    updated.mode = .manualOverride
                    updated.manualPlacements = draft.birthGrahanila.manualPlacements
                }
                draft.birthGrahanila = updated
            }
        }

        // Death Grahanila
        if let death = draft.deathDetails {
            let loc = death.deathLocation ?? .thrissur
            if let grahanila = grahanilaService.calculate(
                date: death.dateOfDeath,
                time: death.deathTime,
                location: loc,
                ayanamsa: ayanamsaSelection
            ) {
                var updated = grahanila
                if draft.deathGrahanila.mode == .manualOverride {
                    updated.mode = .manualOverride
                    updated.manualPlacements = draft.deathGrahanila.manualPlacements
                }
                draft.deathGrahanila = updated
            }
        }
    }

    // MARK: - Event Preview

        /// Returns a pool of panchangam days that spans enough future dates to find the
    /// next upcoming birthday / Śrāddham occurrence, capped at 729 days ahead.
    ///
    /// - If the current year's pool has fewer than 364 future days (i.e. we are past
    ///   roughly January 2 of the viewed year), next year's data is appended so that
    ///   every birth-month can still produce a future occurrence.
    /// - The combined pool is then trimmed to days within 729 days of today so we
    ///   never schedule events more than ~2 years out.
    private func futureDays() async -> [PanchangamDay] {
        guard let location = days.first?.location else { return days }

        let now = Date()
        let cutoff = now.addingTimeInterval(729 * 86_400)   // ~2 years ahead
        let futureCurrent = days.filter { $0.date >= now }

        var pool = days

        // Extend into next year when fewer than 364 future days remain in the
        // current set — guarantees every Malayalam month has a future occurrence.
        if futureCurrent.count < 364 {
            let currentYear = Calendar.current.component(.year, from: days.last?.date ?? now)
            do {
                let nextYearDays = try await panchangamCalculator.calculateYear(
                    year: currentYear + 1,
                    location: location,
                    mode: .keralaTraditional
                )
                pool = days + nextYearDays
            } catch {
                // Fallback: use what we have
            }
        }

        // Trim to the 729-day window so no event is scheduled too far in the future
        return pool.filter { $0.date >= now && $0.date <= cutoff }
    }

    /// Generates preview CalendarEvents for the current draft.
    /// Results are stored in `previewBirthdayEvents` and `previewShraddhamEvents`.
    /// Automatically extends into the next year when needed so the next
    /// upcoming occurrence is always shown, even if the birth month has
    /// already passed this calendar year.
    func previewEvents() async {
        guard !days.isEmpty else { return }
        let extendedDays = await futureDays()
        let now = Date()
        let policy = draft.reminderPreferences.birthdayNakshatraPolicy
        async let birthday = eventGenerator.birthdayEvents(
            for: draft, in: extendedDays,
            policy: policy,
            threshold: duplicateNakshatraThreshold
        )
        async let shraddham = eventGenerator.shraddhamEvents(for: draft, in: extendedDays,
                                                               mode: shraddhamObservanceMode)
        let (bEvents, sEvents) = await (birthday, shraddham)
        previewBirthdayEvents  = bEvents.filter  { $0.startDate > now }
        previewShraddhamEvents = sEvents.filter { $0.startDate > now }
    }

    // MARK: - Export & Schedule (all profiles)

    // Shared helper: build events + alerts for all active profiles.
    // Uses futureDays() to extend into next year when needed, then filters
    // to future-only so past occurrences are never scheduled.
    private func buildAllEventsAndAlerts() async -> (events: [CalendarEvent], alerts: [PanchangamAlert]) {
        let now = Date()
        let extendedDays = await futureDays()
        var allEvents: [CalendarEvent] = []
        var allAlerts: [PanchangamAlert] = []
        for profile in profiles where !profile.isArchived {
            let policy = profile.reminderPreferences.birthdayNakshatraPolicy
            async let bEvents = eventGenerator.birthdayEvents(
                for: profile, in: extendedDays, policy: policy, threshold: duplicateNakshatraThreshold)
            async let sEvents = eventGenerator.shraddhamEvents(for: profile, in: extendedDays,
                                                                   mode: shraddhamObservanceMode)
            async let bAlerts = eventGenerator.birthdayAlerts(
                for: profile, in: extendedDays, policy: policy, threshold: duplicateNakshatraThreshold)
            async let sAlerts = eventGenerator.shraddhamAlerts(for: profile, in: extendedDays,
                                                                   mode: shraddhamObservanceMode)
            let (be, se, ba, sa) = await (bEvents, sEvents, bAlerts, sAlerts)
            allEvents.append(contentsOf: (be + se).filter { $0.startDate > now })
            allAlerts.append(contentsOf: (ba + sa).filter { $0.fireDate > now })
        }
        return (allEvents, allAlerts)
    }

    /// Adds all family events to Apple Calendar only.
    func addToCalendar() async {
        guard !days.isEmpty else {
            errorMessage = "Load a Panchangam year first before exporting events."
            return
        }
        isLoading = true
        defer { isLoading = false }
        let (events, _) = await buildAllEventsAndAlerts()
        do {
            try await calendarService.addEvents(events)
        } catch {
            errorMessage = "Calendar export failed: \(error.localizedDescription)"
        }
    }

    /// Saves family reminders to the app's Reminders page and schedules OS notifications.
    func addToReminders() async {
        guard !days.isEmpty else {
            errorMessage = "Load a Panchangam year first before saving reminders."
            return
        }
        isLoading = true
        defer { isLoading = false }
        let (_, alerts) = await buildAllEventsAndAlerts()

        // Convert PanchangamAlerts → MalayalamReminders so they appear on the Reminders page
        let familyReminders: [MalayalamReminder] = profiles
            .filter { !$0.isArchived }
            .flatMap { profile -> [MalayalamReminder] in
                var items: [MalayalamReminder] = []
                // Birthday reminder
                if profile.reminderPreferences.enableBirthdayReminder,
                   let nak = profile.birthDetails?.birthNakshatra {
                    items.append(MalayalamReminder(
                        name: "\(profile.displayName) — Star Birthday",
                        kind: .birthday,
                        malayalamMonth: profile.birthDetails?.birthMalayalamMonth,
                        nakshatra: nak,
                        reminderTime: profile.reminderPreferences.birthdayReminderTime,
                        advanceMinutes: profile.reminderPreferences.birthdayReminderAdvanceMinutes,
                        location: profile.birthDetails?.birthLocation ?? .thrissur
                    ))
                }
                // Śrāddham reminder
                if profile.isDeceased,
                   profile.reminderPreferences.enableShraddhamReminder,
                   let tithi = profile.deathDetails?.deathTithi {
                    items.append(MalayalamReminder(
                        name: "\(profile.displayName) — Śrāddham",
                        kind: .deathAnniversary,
                        tithi: tithi.englishName,
                        reminderTime: profile.reminderPreferences.shraddhamReminderTime,
                        advanceMinutes: profile.reminderPreferences.shraddhamReminderAdvanceMinutes,
                        location: profile.deathDetails?.deathLocation ?? .thrissur
                    ))
                }
                return items
            }

        // Persist alongside existing reminders
        do {
            let existing = (try? await reminderStore.loadReminders()) ?? []
            // Remove stale family reminders with the same name before adding fresh ones
            let familyNames = Set(familyReminders.map(\.name))
            let kept = existing.filter { !familyNames.contains($0.name) }
            try await reminderStore.saveReminders(kept + familyReminders)
        } catch {
            errorMessage = "Saving reminders failed: \(error.localizedDescription)"
        }

        // Schedule OS notifications
        for alert in alerts {
            try? await notificationService.schedule(alert: alert)
        }
    }

    /// Legacy combined method (kept for compatibility).
    func exportAndSchedule() async {
        await addToCalendar()
        await addToReminders()
    }

    // MARK: - Calendar Highlights

    /// Rebuilds `birthHighlights`, `deathHighlights`, `shraddhamDates`, and
    /// the cached Nakshatra Sets from the current `profiles` and `days`.
    /// Call after loading profiles or when `days` changes.
    func refreshHighlights() {
        birthHighlights = profiles
            .filter { !$0.isArchived }
            .compactMap { profile -> NakshatraHighlight? in
                guard let nakshatra = profile.birthDetails?.birthNakshatra else { return nil }
                return NakshatraHighlight(
                    nakshatra: nakshatra,
                    kind: .birthday,
                    personName: profile.displayName,
                    personID: profile.id
                )
            }

        deathHighlights = profiles
            .filter { !$0.isArchived && $0.isDeceased }
            .compactMap { profile -> NakshatraHighlight? in
                guard let nakshatra = profile.deathDetails?.deathNakshatra else { return nil }
                return NakshatraHighlight(
                    nakshatra: nakshatra,
                    kind: .deathDay,
                    personName: profile.displayName,
                    personID: profile.id
                )
            }

        // Cache sets once so calendar-view cells do O(1) lookups without
        // rebuilding the Set on every body evaluation.
        birthNakshatraSet = Set(birthHighlights.map(\.nakshatra))
        deathNakshatraSet = Set(deathHighlights.map(\.nakshatra))

        guard !days.isEmpty else { return }
        shraddhamDates = profiles
            .filter { !$0.isArchived && $0.isDeceased }
            .flatMap { shraddhamFinder.shraddhamDates(for: $0, in: days, mode: shraddhamObservanceMode) }
            .sorted { $0.gregorianDate < $1.gregorianDate }

        // Rebuild the date-keyed event map in the background so calendar cells
        // can show yellow event labels without blocking the main thread.
        Task { await refreshFamilyEventDates() }
    }

    // MARK: - Family Event Date Map

    /// Builds `familyEventsByDate` — the dictionary that calendar cells query to
    /// show upcoming birthday and Śrāddham labels in yellow text.
    private func refreshFamilyEventDates() async {
        guard !days.isEmpty else {
            familyEventsByDate = [:]
            return
        }
        let extendedDays = await futureDays()
        let now = Date()
        let locationTZ  = days.first?.location.timeZone ?? TimeZone.current
        var byDate: [String: [FamilyDayEvent]] = [:]

        for profile in profiles where !profile.isArchived {
            let policy = profile.reminderPreferences.birthdayNakshatraPolicy

            // Birthday events
            if profile.reminderPreferences.enableBirthdayReminder,
               profile.birthDetails?.birthNakshatra != nil {
                let bEvents = await eventGenerator.birthdayEvents(
                    for: profile, in: extendedDays,
                    policy: policy,
                    threshold: duplicateNakshatraThreshold)
                for event in bEvents where event.startDate >= now {
                    let key = isoDateKey(for: event.startDate, timeZone: locationTZ)
                    byDate[key, default: []].append(
                        FamilyDayEvent(id: event.id,
                                       label: "★ \(profile.displayName)",
                                       title: event.title,
                                       kind: .birthday))
                }
            }

            // Śrāddham events (either nakshatra or tithi depending on mode)
            if profile.isDeceased,
               profile.reminderPreferences.enableShraddhamReminder,
               profile.deathDetails != nil {
                let sEvents = await eventGenerator.shraddhamEvents(for: profile, in: extendedDays,
                                                                       mode: shraddhamObservanceMode)
                for event in sEvents where event.startDate >= now {
                    let key = isoDateKey(for: event.startDate, timeZone: locationTZ)
                    byDate[key, default: []].append(
                        FamilyDayEvent(id: event.id,
                                       label: "† \(profile.displayName)",
                                       title: event.title,
                                       kind: .deathDay))
                }
            }
        }
        familyEventsByDate = byDate
    }

    /// Returns an ISO "YYYY-MM-DD" key for `date` in `timeZone`, matching
    /// the format used by `PanchangamDay.isoDateKey`.
    private func isoDateKey(for date: Date, timeZone: TimeZone) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    // MARK: - Computed helpers

    /// The profile currently being viewed/edited (matches `selectedProfileID`).
    var selectedProfile: PersonProfile? {
        guard let id = selectedProfileID else { return nil }
        return profiles.first { $0.id == id }
    }

    /// Active (non-archived) profiles sorted by display name.
    var activeProfiles: [PersonProfile] {
        profiles
            .filter { !$0.isArchived }
            .sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
    }

    /// Cached Set for O(1) birthday-star lookup — updated by `refreshHighlights()`.
    private(set) var birthNakshatraSet: Set<Nakshatra> = []

    /// Cached Set for O(1) death-star lookup — updated by `refreshHighlights()`.
    private(set) var deathNakshatraSet: Set<Nakshatra> = []

    // MARK: - Date + Time Combiners

    /// Combines the calendar date from `date` with the clock time from `time`,
    /// both interpreted in `timezone`.
    ///
    /// Used by PersonFormView to anchor the DatePicker's hour/minute onto the
    /// correct date. Both the date and time components are extracted in the same
    /// timezone (the Mac's system timezone, `.current`), so the displayed
    /// hour/minute value is preserved exactly as the user typed it.
    static func combine(date: Date, time: Date, in timezone: TimeZone) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timezone

        let dateComponents = cal.dateComponents([.year, .month, .day], from: date)
        let timeComponents = cal.dateComponents([.hour, .minute, .second], from: time)

        var combined        = DateComponents()
        combined.year       = dateComponents.year
        combined.month      = dateComponents.month
        combined.day        = dateComponents.day
        combined.hour       = timeComponents.hour ?? 0
        combined.minute     = timeComponents.minute ?? 0
        combined.second     = timeComponents.second ?? 0
        combined.timeZone   = timezone

        return cal.date(from: combined) ?? date
    }

    /// Builds the exact UTC moment for a birth or death event, correctly handling
    /// a mismatch between the Mac's system timezone and the event's location timezone.
    ///
    /// **Why this matters:** The Mac's DatePicker always shows times in the system
    /// timezone (e.g. Asia/Qatar). When a user in Qatar types "1:32 PM" for a birth
    /// that happened in Kerala (IST), they mean 1:32 PM IST — that is the time on
    /// the birth certificate. But the stored `Date` represents 1:32 PM Qatar time
    /// (= 10:32 UTC), not 1:32 PM IST (= 08:02 UTC).
    ///
    /// This function recovers the user's *intended* time by:
    /// 1. Reading the hour/minute that were **displayed** on the Mac (using `TimeZone.current`).
    /// 2. Placing those hour/minute on `date` in the **location timezone** (IST).
    ///
    /// Result: Jan 22 2007 13:32 IST = 08:02 UTC  ✓
    static func combineDisplayedTime(date: Date,
                                     displayedTime: Date,
                                     locationTimeZone: TimeZone) -> Date {
        // Step 1: recover the hour/minute as shown on the Mac
        var displayCal = Calendar(identifier: .gregorian)
        displayCal.timeZone = TimeZone.current
        let timeComps = displayCal.dateComponents([.hour, .minute, .second], from: displayedTime)

        // Step 2: apply those components on the correct date in the location timezone
        var locationCal = Calendar(identifier: .gregorian)
        locationCal.timeZone = locationTimeZone
        let dateComps = locationCal.dateComponents([.year, .month, .day], from: date)

        var combined        = DateComponents()
        combined.year       = dateComps.year
        combined.month      = dateComps.month
        combined.day        = dateComps.day
        combined.hour       = timeComps.hour ?? 0
        combined.minute     = timeComps.minute ?? 0
        combined.second     = timeComps.second ?? 0
        combined.timeZone   = locationTimeZone

        return locationCal.date(from: combined) ?? date
    }

    // MARK: - Private persistence

    private func persistProfiles() async {
        do {
            try await store.saveProfiles(profiles)
        } catch {
            errorMessage = "Failed to save profiles: \(error.localizedDescription)"
        }
    }
}
