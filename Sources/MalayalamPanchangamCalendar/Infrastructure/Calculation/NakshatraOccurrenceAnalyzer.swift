import Foundation

// MARK: - Analyzer

/// Groups `PanchangamDay`s for a given nakshatra + Malayalam month into
/// consecutive runs ("occurrences"), computes per-occurrence durations and
/// transition times, then applies the configured policy to mark which
/// occurrence is recommended.
struct NakshatraOccurrenceAnalyzer {

    // MARK: - Public API

    func analyze(
        nakshatra: Nakshatra,
        month: MalayalamMonth,
        in days: [PanchangamDay],
        policy: DuplicateNakshatraPolicy,
        threshold: DuplicateNakshatraThreshold
    ) -> NakshatraOccurrenceAnalysis {

        // 1. Filter to days that belong to this nakshatra AND month.
        let matchingDays = days.filter {
            $0.mainNakshatra == nakshatra && $0.malayalamMonth == month
        }

        guard !matchingDays.isEmpty else {
            return NakshatraOccurrenceAnalysis(
                nakshatra: nakshatra,
                month: month,
                occurrences: [],
                policy: policy,
                threshold: threshold
            )
        }

        // 2. Split into consecutive date runs.
        var runs: [[PanchangamDay]] = []
        var currentRun: [PanchangamDay] = [matchingDays[0]]
        let cal = Calendar(identifier: .gregorian)

        for i in 1..<matchingDays.count {
            let prev = matchingDays[i - 1]
            let curr = matchingDays[i]
            let expectedNext = cal.date(byAdding: .day, value: 1, to: prev.date) ?? prev.date
            if cal.isDate(curr.date, inSameDayAs: expectedNext) {
                currentRun.append(curr)
            } else {
                runs.append(currentRun)
                currentRun = [curr]
            }
        }
        runs.append(currentRun)

        // 3. Build NakshatraOccurrence objects.
        var occurrences: [NakshatraOccurrence] = runs.enumerated().map { index, run in
            NakshatraOccurrence(
                occurrenceNumber: index + 1,
                days: run,
                totalDuration: totalDuration(for: nakshatra, in: run),
                transitionInTime: firstTransitionIn(for: nakshatra, in: run),
                transitionOutTime: lastTransitionOut(for: nakshatra, in: run)
            )
        }

        // 4. Apply policy to annotate isRecommended + reasoning.
        occurrences = applyPolicy(policy, threshold: threshold, to: occurrences, in: days)

        return NakshatraOccurrenceAnalysis(
            nakshatra: nakshatra,
            month: month,
            occurrences: occurrences,
            policy: policy,
            threshold: threshold
        )
    }

    // MARK: - Duration helpers

    private func totalDuration(for nakshatra: Nakshatra, in run: [PanchangamDay]) -> TimeInterval {
        run.reduce(0) { total, day in
            total + day.nakshatraPeriods
                .filter { $0.nakshatra == nakshatra }
                .reduce(0) { $0 + $1.duration }
        }
    }

    private func firstTransitionIn(for nakshatra: Nakshatra, in run: [PanchangamDay]) -> Date? {
        guard let firstDay = run.first else { return nil }
        return firstDay.nakshatraPeriods
            .filter { $0.nakshatra == nakshatra }
            .min(by: { $0.start < $1.start })?
            .start
    }

    private func lastTransitionOut(for nakshatra: Nakshatra, in run: [PanchangamDay]) -> Date? {
        guard let lastDay = run.last else { return nil }
        return lastDay.nakshatraPeriods
            .filter { $0.nakshatra == nakshatra }
            .max(by: { $0.end < $1.end })?
            .end
    }

    // MARK: - Solar day duration

    /// Sunrise-to-sunrise duration for the first day of `occurrence`.
    /// Falls back to 86 400 s when the next day is not in the provided array.
    private func solarDayDuration(
        for occurrence: NakshatraOccurrence,
        in allDays: [PanchangamDay]
    ) -> TimeInterval {
        guard let firstDay = occurrence.firstDay else { return 86_400 }
        let cal = Calendar(identifier: .gregorian)
        guard let nextDate = cal.date(byAdding: .day, value: 1, to: firstDay.date),
              let nextDay = allDays.first(where: { cal.isDate($0.date, inSameDayAs: nextDate) })
        else {
            return 86_400
        }
        let d = nextDay.sunrise.timeIntervalSince(firstDay.sunrise)
        return d > 0 ? d : 86_400
    }

    // MARK: - Policy application

    private func applyPolicy(
        _ policy: DuplicateNakshatraPolicy,
        threshold: DuplicateNakshatraThreshold,
        to occurrences: [NakshatraOccurrence],
        in allDays: [PanchangamDay]
    ) -> [NakshatraOccurrence] {
        guard !occurrences.isEmpty else { return occurrences }

        // Single occurrence — trivially recommended.
        if occurrences.count == 1 {
            var o = occurrences[0]
            o.isRecommended = true
            o.reasoning = "Only occurrence this month."
            return [o]
        }

        var result = occurrences

        switch policy {

        case .alwaysSecond:
            markNone(&result)
            result[1].isRecommended = true
            result[1].reasoning = "Second occurrence — selected by 'Always Second' policy."
            result[0].reasoning = "Second occurrence preferred by policy."

        case .alwaysFirst:
            markNone(&result)
            result[0].isRecommended = true
            result[0].reasoning = "First occurrence — selected by 'Always First' policy."
            if result.count > 1 {
                result[1].reasoning = "First occurrence preferred by policy."
            }

        case .longestDuration:
            markNone(&result)
            if let idx = result.indices.max(by: { result[$0].totalDuration < result[$1].totalDuration }) {
                result[idx].isRecommended = true
                result[idx].reasoning = "Longest duration (\(result[idx].durationLabel)) — selected by policy."
            }
            for i in result.indices where !result[i].isRecommended {
                result[i].reasoning = "Shorter duration (\(result[i].durationLabel))."
            }

        case .preferSecondUnlessShort:
            markNone(&result)
            let second = result[1]
            let dayDur = solarDayDuration(for: second, in: allDays)
            if threshold.isShort(duration: second.totalDuration, dayDuration: dayDur) {
                result[0].isRecommended = true
                result[0].reasoning = "Second occurrence is too short (\(second.durationLabel) < \(threshold.displayString)); using first."
                result[1].reasoning = "Too short (\(second.durationLabel) < \(threshold.displayString)) — first occurrence used instead."
            } else {
                result[1].isRecommended = true
                result[1].reasoning = "Second occurrence preferred (\(second.durationLabel) ≥ \(threshold.displayString))."
                result[0].reasoning = "Second occurrence preferred by policy."
            }

        case .askEveryYear:
            for i in result.indices {
                result[i].isRecommended = false
                result[i].reasoning = "Review and choose manually — 'Ask Every Year' policy active."
            }
        }

        return result
    }

    private func markNone(_ occurrences: inout [NakshatraOccurrence]) {
        for i in occurrences.indices {
            occurrences[i].isRecommended = false
            occurrences[i].reasoning = ""
        }
    }
}
