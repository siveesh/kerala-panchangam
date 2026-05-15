import Foundation

actor DefaultPanchangamValidator: PanchangamValidator {
    private let sources: [ReferenceValidationSource]
    private let strictness: ValidationStrictness

    init(
        sources: [ReferenceValidationSource] = [
            HistoricalArchiveValidationSource(),
            OnlinePanchangamValidationSource(sourceName: "Drik Panchang"),
            OnlinePanchangamValidationSource(sourceName: "Prokerala"),
            OnlinePanchangamValidationSource(sourceName: "Mathrubhumi Panchangam"),
            OnlinePanchangamValidationSource(sourceName: "Manorama Calendar")
        ],
        strictness: ValidationStrictness = .standard
    ) {
        self.sources = sources
        self.strictness = strictness
    }

    func validate(day: PanchangamDay) async -> ValidationResult {
        let calculated = ValidationValueSet(
            sunrise: day.sunrise,
            sunset: day.sunset,
            nakshatra: day.mainNakshatra,
            nakshatraTransition: day.nakshatraTransition,
            malayalamMonth: day.malayalamMonth,
            malayalamDay: day.malayalamDay,
            rahuKalam: day.rahuKalam,
            yamagandam: day.yamagandam,
            gulikaKalam: day.gulikaKalam
        )

        for source in sources {
            if let expected = await source.expectedValues(for: day) {
                return compare(sourceName: source.sourceName, expected: expected, calculated: calculated)
            }
        }

        return ValidationResult(
            sourceName: "No Reference Source",
            expectedValues: ValidationValueSet(),
            calculatedValues: calculated,
            delta: ValidationDelta(),
            passed: false,
            confidenceScore: 0.25,
            notes: "Validation sources are scaffolded. Add archival fixtures or online adapters before treating astronomical output as authoritative."
        )
    }

    private func compare(sourceName: String, expected: ValidationValueSet, calculated: ValidationValueSet) -> ValidationResult {
        let delta = ValidationDelta(
            sunriseSeconds: seconds(expected.sunrise, calculated.sunrise),
            sunsetSeconds: seconds(expected.sunset, calculated.sunset),
            nakshatraTransitionSeconds: seconds(expected.nakshatraTransition, calculated.nakshatraTransition),
            rahuKalamSeconds: seconds(expected.rahuKalam?.start, calculated.rahuKalam?.start),
            yamagandamSeconds: seconds(expected.yamagandam?.start, calculated.yamagandam?.start),
            gulikaKalamSeconds: seconds(expected.gulikaKalam?.start, calculated.gulikaKalam?.start)
        )

        let passed = passes(delta: delta)
            && (expected.nakshatra == nil || expected.nakshatra == calculated.nakshatra)
            && (expected.malayalamMonth == nil || expected.malayalamMonth == calculated.malayalamMonth)
            && (expected.malayalamDay == nil || expected.malayalamDay == calculated.malayalamDay)

        return ValidationResult(
            sourceName: sourceName,
            expectedValues: expected,
            calculatedValues: calculated,
            delta: delta,
            passed: passed,
            confidenceScore: passed ? 0.95 : 0.55
        )
    }

    private func passes(delta: ValidationDelta) -> Bool {
        let sunriseTolerance: TimeInterval = 120
        let transitionTolerance: TimeInterval = strictness == .strict ? 180 : 300
        let periodTolerance: TimeInterval = 120
        let values: [(TimeInterval?, TimeInterval)] = [
            (delta.sunriseSeconds, sunriseTolerance),
            (delta.sunsetSeconds, sunriseTolerance),
            (delta.nakshatraTransitionSeconds, transitionTolerance),
            (delta.rahuKalamSeconds, periodTolerance),
            (delta.yamagandamSeconds, periodTolerance),
            (delta.gulikaKalamSeconds, periodTolerance)
        ]
        return values.allSatisfy { value, tolerance in
            guard let value else { return true }
            return abs(value) <= tolerance
        }
    }

    private func seconds(_ expected: Date?, _ calculated: Date?) -> TimeInterval? {
        guard let expected, let calculated else { return nil }
        return calculated.timeIntervalSince(expected)
    }
}
