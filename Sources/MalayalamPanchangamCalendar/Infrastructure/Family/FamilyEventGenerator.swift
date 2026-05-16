import Foundation

// MARK: - FamilyEventGenerator

/// Generates CalendarEvents and PanchangamAlerts for family members.
/// Birthday logic reuses NakshatraOccurrenceAnalyzer directly.
/// Śrāddham logic delegates to ShraddhamDateFinder.
struct FamilyEventGenerator: FamilyEventGenerating {

    private let analyzer = NakshatraOccurrenceAnalyzer()
    private let shraddhamFinder = ShraddhamDateFinder()

    // MARK: - Birthday Events

    func birthdayEvents(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        policy: DuplicateNakshatraPolicy,
        threshold: DuplicateNakshatraThreshold
    ) async -> [CalendarEvent] {
        birthdayDays(for: profile, in: days, policy: policy, threshold: threshold)
            .map { day in
                CalendarEvent(
                    title: "\(profile.displayName) Star Birthday",
                    startDate: eventDate(for: day, reminderPreferences: profile.reminderPreferences, isBirthday: true),
                    endDate: eventDate(for: day, reminderPreferences: profile.reminderPreferences, isBirthday: true)
                        .addingTimeInterval(30 * 60),
                    notes: birthdayNotes(profile: profile, day: day),
                    sourceReminderID: nil
                )
            }
    }

    // MARK: - Śrāddham Events

    func shraddhamEvents(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        mode: ShraddhamObservanceMode = .nakshatraOnly
    ) async -> [CalendarEvent] {
        guard profile.isDeceased else { return [] }
        return shraddhamDates(for: profile, in: days, mode: mode)
            .map { shraddham in
                CalendarEvent(
                    title: "\(profile.displayName) Śrāddham",
                    startDate: shraddham.gregorianDate,
                    endDate: shraddham.gregorianDate.addingTimeInterval(30 * 60),
                    notes: shraddhamNotes(profile: profile, shraddham: shraddham),
                    sourceReminderID: nil
                )
            }
    }

    // MARK: - Birthday Alerts

    func birthdayAlerts(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        policy: DuplicateNakshatraPolicy,
        threshold: DuplicateNakshatraThreshold
    ) async -> [PanchangamAlert] {
        guard profile.reminderPreferences.enableBirthdayReminder else { return [] }
        let prefs = profile.reminderPreferences
        return birthdayDays(for: profile, in: days, policy: policy, threshold: threshold)
            .map { day in
                let fireDate = eventDate(for: day, reminderPreferences: prefs, isBirthday: true)
                    .addingTimeInterval(-Double(prefs.birthdayReminderAdvanceMinutes) * 60)
                let nakshatra = day.mainNakshatra.englishName
                let date = "\(day.malayalamMonth.englishName) \(day.malayalamDay)"
                return PanchangamAlert(
                    title: "\(profile.displayName) Star Birthday",
                    body: "Nakshatra: \(nakshatra)\nMalayalam Date: \(date)",
                    fireDate: fireDate,
                    isSilent: false
                )
            }
    }

    // MARK: - Śrāddham Alerts

    func shraddhamAlerts(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        mode: ShraddhamObservanceMode = .nakshatraOnly
    ) async -> [PanchangamAlert] {
        guard profile.isDeceased,
              profile.reminderPreferences.enableShraddhamReminder else { return [] }
        let prefs = profile.reminderPreferences
        return shraddhamDates(for: profile, in: days, mode: mode)
            .map { shraddham in
                let fireDate = shraddham.gregorianDate
                    .addingTimeInterval(-Double(prefs.shraddhamReminderAdvanceMinutes) * 60)
                return PanchangamAlert(
                    title: "\(profile.displayName) Śrāddham",
                    body: "Tithi: \(shraddham.paksha.shortName) \(shraddham.tithi.englishName)\n\(shraddham.malayalamDateLabel)",
                    fireDate: fireDate,
                    isSilent: false
                )
            }
    }

    // MARK: - Private helpers

    private func birthdayDays(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        policy: DuplicateNakshatraPolicy,
        threshold: DuplicateNakshatraThreshold
    ) -> [PanchangamDay] {
        guard let birth = profile.birthDetails,
              let nakshatra = birth.birthNakshatra,
              let month = birth.birthMalayalamMonth else { return [] }

        // CRITICAL: split the day pool into one slice per annual occurrence of the
        // birth month, then call the analyser independently on each slice.
        //
        // We CANNOT group by `day.kollavarshamYear` because that field is computed
        // from the Gregorian year, and some Malayalam months (Dhanu, Makaram) straddle
        // the Gregorian year boundary. For example, Dhanu runs from ~Dec 16 to ~Jan 13:
        //   • Dec 16–31, 2026 → year=2026, Dhanu  → kollavarshamYear = 2026−824 = 1202 ✓
        //   • Jan  1–13, 2027 → year=2027, Dhanu  → kollavarshamYear = 2027−824 = 1203 ✗
        //     (still Dhanu 1202, but formula says 1203)
        //   • Dec 16–31, 2027 → year=2027, Dhanu  → kollavarshamYear = 2027−824 = 1203 ✓
        // This causes Jan 1–13, 2027 and Dec 16–31, 2027 to land in the same bucket (1203),
        // so the analyser sees two Thiruvonam runs inside "1203" and applies the duplicate
        // policy — dropping the Jan 9 date.
        //
        // Correct approach: group into consecutive runs of the birth month. Each unbroken
        // run of days with `malayalamMonth == birthMonth` is exactly one annual occurrence,
        // regardless of Gregorian year boundary.
        let monthInstances = Self.consecutiveMonthInstances(of: month, in: days)

        // Community standard (confirmed by astrologer): for all auspicious events
        // (birthdays, star anniversaries) the SECOND occurrence of the nakshatra is
        // observed when the month contains two runs of that nakshatra. The first
        // occurrence is skipped. When only one occurrence exists the single run is
        // used automatically regardless of policy.
        // Śrāddham (death anniversary) uses the FIRST occurrence — see ShraddhamDateFinder.
        //
        // A nakshatra can be the sunrise-nakshatra on two consecutive days when it
        // spans overnight. We take only the FIRST day of the recommended occurrence
        // so exactly one birthday event is generated per annual occurrence.
        return monthInstances.flatMap { instanceDays in
            analyzer.analyze(
                nakshatra: nakshatra,
                month: month,
                in: instanceDays,
                policy: .alwaysSecond,
                threshold: threshold
            ).recommendedDays.prefix(1)
        }
    }

    private func shraddhamDates(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        mode: ShraddhamObservanceMode = .nakshatraOnly
    ) -> [ShraddhamDate] {
        shraddhamFinder.shraddhamDates(for: profile, in: days, mode: mode)
    }

    /// Splits `days` into contiguous runs where each run has `day.malayalamMonth == month`.
    /// Each run is one annual occurrence of that month, free of Gregorian-year-boundary
    /// artifacts (unlike grouping by `kollavarshamYear`, which mis-assigns the January
    /// tail of cross-year months like Dhanu and Makaram to the wrong KE year).
    static func consecutiveMonthInstances(
        of month: MalayalamMonth,
        in days: [PanchangamDay]
    ) -> [[PanchangamDay]] {
        let filtered = days.filter { $0.malayalamMonth == month }
                           .sorted { $0.date < $1.date }
        guard !filtered.isEmpty else { return [] }

        let cal = Calendar(identifier: .gregorian)
        var instances: [[PanchangamDay]] = []
        var current: [PanchangamDay] = [filtered[0]]

        for i in 1..<filtered.count {
            let prev = filtered[i - 1]
            let next = filtered[i]
            let expectedNext = cal.date(byAdding: .day, value: 1, to: prev.date) ?? prev.date
            if cal.isDate(next.date, inSameDayAs: expectedNext) {
                current.append(next)
            } else {
                instances.append(current)
                current = [next]
            }
        }
        instances.append(current)
        return instances
    }

    /// Build the event fire date from the Panchangam day + reminder time preference.
    private func eventDate(
        for day: PanchangamDay,
        reminderPreferences prefs: FamilyReminderPreferences,
        isBirthday: Bool
    ) -> Date {
        let time = isBirthday ? prefs.birthdayReminderTime : prefs.shraddhamReminderTime
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = day.location.timeZone
        var components = cal.dateComponents([.year, .month, .day], from: day.date)
        components.hour = time.hour ?? 7
        components.minute = time.minute ?? 0
        components.second = 0
        return cal.date(from: components) ?? day.sunrise
    }

    private func birthdayNotes(profile: PersonProfile, day: PanchangamDay) -> String {
        var lines = [
            "Person: \(profile.displayName)",
            "Event: Star Birthday",
            "Nakshatra: \(day.mainNakshatra.englishName) / \(day.mainNakshatra.malayalamName)",
            "Malayalam Date: \(day.malayalamMonth.englishName) \(day.malayalamDay), \(day.kollavarshamYear)",
            "Location: \(day.location.name)",
            "Generated as an individual event, not an EventKit recurring rule."
        ]
        if let birth = profile.birthDetails, let dob = birth.birthMalayalamMonth {
            lines.insert("Birth Month: \(dob.englishName)", at: 3)
        }
        return lines.joined(separator: "\n")
    }

    private func shraddhamNotes(profile: PersonProfile, shraddham: ShraddhamDate) -> String {
        [
            "Person: \(profile.displayName)",
            "Event: Śrāddham",
            "Tithi: \(shraddham.paksha.shortName) \(shraddham.tithi.englishName)",
            "Date: \(shraddham.malayalamDateLabel)",
            "Rule: \(shraddham.selectionRuleDescription)",
            "Generated as an individual event, not an EventKit recurring rule.",
            "Disclaimer: Verify with family tradition or a trusted astrologer/priest."
        ].joined(separator: "\n")
    }
}
