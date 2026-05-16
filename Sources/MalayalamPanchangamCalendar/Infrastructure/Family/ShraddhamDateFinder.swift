import Foundation

// MARK: - ShraddhamDateFinder

/// Finds the annual Śrāddham observance date for a deceased person.
///
/// Nakshatra-based finding groups days into **consecutive runs of the death month**
/// (via `FamilyEventGenerator.consecutiveMonthInstances`). This correctly handles
/// Malayalam months that straddle the Gregorian year boundary (Dhanu Dec–Jan,
/// Makaram Jan–Feb), where grouping by `kollavarshamYear` would mis-assign the
/// January tail to the next KE year and merge two separate annual occurrences.
///
/// The mode parameter controls whether the date is determined by nakshatra, tithi,
/// or both — mirroring the user's global `ShraddhamObservanceMode` setting.
struct ShraddhamDateFinder: Sendable {

    var tithiRule: any TithiSelectionRule = SunriseTithiSelectionRule()
    private let analyzer = NakshatraOccurrenceAnalyzer()

    // MARK: - Public API

    func shraddhamDates(
        for profile: PersonProfile,
        in days: [PanchangamDay],
        mode: ShraddhamObservanceMode
    ) -> [ShraddhamDate] {
        guard let death = profile.deathDetails else { return [] }

        switch mode {
        case .nakshatraOnly:
            return nakshatraDates(for: death, profile: profile, in: days)

        case .nakshatraPreferred:
            let results = nakshatraDates(for: death, profile: profile, in: days)
            return results.isEmpty ? tithiDates(for: death, profile: profile, in: days) : results

        case .tithiPreferred:
            let results = tithiDates(for: death, profile: profile, in: days)
            return results.isEmpty ? nakshatraDates(for: death, profile: profile, in: days) : results

        case .tithiAndNakshatra:
            // Both dates per year; deduplicate by gregorian date in case they coincide.
            let tithi    = tithiDates(for: death, profile: profile, in: days)
            let nakshatra = nakshatraDates(for: death, profile: profile, in: days)
            var seen = Set<String>()
            return (tithi + nakshatra).filter { seen.insert($0.gregorianDateKey).inserted }
        }
    }

    // MARK: - Nakshatra-based finding (Kerala traditional)

    /// Finds the day in each annual instance of the death Malayalam month
    /// where the death nakshatra falls.
    private func nakshatraDates(
        for death: DeathDetails,
        profile: PersonProfile,
        in days: [PanchangamDay]
    ) -> [ShraddhamDate] {
        guard let nakshatra = death.deathNakshatra,
              let month     = death.deathMalayalamMonth else { return [] }

        // Use consecutive-run grouping (not kollavarshamYear) to correctly handle
        // cross-Gregorian-year months like Dhanu (Dec–Jan) and Makaram (Jan–Feb).
        // The kollavarshamYear field is computed from the Gregorian year and mis-assigns
        // Jan 1–13 of Dhanu to the next KE year, causing two separate annual occurrences
        // to land in the same group where the duplicate policy then drops one of them.
        let monthInstances = FamilyEventGenerator.consecutiveMonthInstances(of: month, in: days)

        return monthInstances.flatMap { instanceDays -> [ShraddhamDate] in
            // Community standard (confirmed by astrologer): Śrāddham observes the
            // FIRST occurrence of the death nakshatra in the month. This is the
            // opposite of auspicious events (birthdays) which use the second occurrence.
            let recommended = analyzer.analyze(
                nakshatra: nakshatra,
                month: month,
                in: instanceDays,
                policy: .alwaysFirst,
                threshold: .default
            ).recommendedDays

            return recommended.map { day in
                ShraddhamDate(
                    personID: profile.id,
                    personName: profile.displayName,
                    gregorianDate: day.date,
                    tithi: day.tithi,
                    paksha: Paksha.from(day.tithi),
                    malayalamDateLabel: "\(day.malayalamMonth.englishName) \(day.malayalamDay) · \(day.kollavarshamYear)",
                    selectionRuleDescription: "Nakshatra: \(nakshatra.englishName) in \(month.englishName)"
                )
            }
        }
    }

    // MARK: - Tithi-based finding

    /// Finds the day each Kollavarsham year where the sunrise tithi matches the death tithi.
    /// Tithi-based search scans the whole-year pool without month filtering, so we group
    /// by actual Kollavarsham year. The kollavarshamYear bug only affects month-boundary
    /// months; for tithi search we use the whole year's days, so a year-based split is fine.
    private func tithiDates(
        for death: DeathDetails,
        profile: PersonProfile,
        in days: [PanchangamDay]
    ) -> [ShraddhamDate] {
        guard let deathTithi = death.deathTithi else { return [] }

        // For tithi-based search we scan ALL days in each Kollavarsham year (no month filter).
        // Group by the actual start of each KE year: use Chingam as the year-start anchor.
        // Simple approach: group by the computed "KE year of Chingam" for each day.
        // Because Chingam always falls in August (Gregorian), its KE year = gregorianYear - 824
        // and is always consistent. We derive a stable year key from Chingam's position.
        //
        // Simpler still: group by kollavarshamYear where the month is NOT a cross-year month,
        // or just group by kollavarshamYear directly — tithi search doesn't filter by month,
        // so having Jan 1–13 in the "wrong" KE group doesn't cause double-counting; we just
        // pick one day per group that matches the tithi.
        let grouped = Dictionary(grouping: days) { $0.kollavarshamYear }

        var results: [ShraddhamDate] = []
        for (_, yearDays) in grouped.sorted(by: { $0.key < $1.key }) {
            let candidates = yearDays.filter { $0.tithi == deathTithi }
            guard let selected = tithiRule.selectDay(from: candidates, tithi: deathTithi) else {
                continue  // kshaya tithi year — no matching day; skip
            }
            let paksha = Paksha.from(deathTithi)
            results.append(ShraddhamDate(
                personID: profile.id,
                personName: profile.displayName,
                gregorianDate: selected.date,
                tithi: deathTithi,
                paksha: paksha,
                malayalamDateLabel: "\(selected.malayalamMonth.englishName) \(selected.malayalamDay) · \(selected.kollavarshamYear)",
                selectionRuleDescription: "Tithi: \(paksha.shortName) \(deathTithi.englishName) (\(tithiRule.displayName))"
            ))
        }
        return results
    }
}

// MARK: - ShraddhamDate extension

private extension ShraddhamDate {
    var gregorianDateKey: String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: gregorianDate)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
