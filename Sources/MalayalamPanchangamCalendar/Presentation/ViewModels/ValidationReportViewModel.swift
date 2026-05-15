import Foundation
import Observation

@MainActor
@Observable
final class ValidationReportViewModel {
    var result: ValidationResult?
    var isValidating = false
    var errorMessage: String?

    private let validator: PanchangamValidator

    init(validator: PanchangamValidator = DefaultPanchangamValidator()) {
        self.validator = validator
    }

    func validate(day: PanchangamDay) async {
        isValidating = true
        errorMessage = nil
        defer { isValidating = false }
        result = await validator.validate(day: day)
    }

    func clear() {
        result = nil
        errorMessage = nil
    }
}

struct ValidationReportRow: Identifiable, Sendable {
    let id: String
    let label: String
    let expected: String
    let calculated: String
    let delta: String
    let passed: Bool?
}

enum ValidationReportFormatter {
    static func rows(for result: ValidationResult, timeZone: TimeZone) -> [ValidationReportRow] {
        [
            row(
                id: "sunrise",
                label: "Sunrise",
                expected: result.expectedValues.sunrise.map { PanchangamFormatters.time($0, timeZone: timeZone) },
                calculated: result.calculatedValues.sunrise.map { PanchangamFormatters.time($0, timeZone: timeZone) },
                delta: result.delta.sunriseSeconds,
                tolerance: 120
            ),
            row(
                id: "sunset",
                label: "Sunset",
                expected: result.expectedValues.sunset.map { PanchangamFormatters.time($0, timeZone: timeZone) },
                calculated: result.calculatedValues.sunset.map { PanchangamFormatters.time($0, timeZone: timeZone) },
                delta: result.delta.sunsetSeconds,
                tolerance: 120
            ),
            valueRow(
                id: "nakshatra",
                label: "Nakshatra",
                expected: result.expectedValues.nakshatra?.englishName,
                calculated: result.calculatedValues.nakshatra?.englishName
            ),
            row(
                id: "transition",
                label: "Nakshatra Transition",
                expected: result.expectedValues.nakshatraTransition.map { PanchangamFormatters.time($0, timeZone: timeZone) },
                calculated: result.calculatedValues.nakshatraTransition.map { PanchangamFormatters.time($0, timeZone: timeZone) },
                delta: result.delta.nakshatraTransitionSeconds,
                tolerance: 300
            ),
            valueRow(
                id: "malayalam-date",
                label: "Malayalam Date",
                expected: malayalamDate(month: result.expectedValues.malayalamMonth, day: result.expectedValues.malayalamDay),
                calculated: malayalamDate(month: result.calculatedValues.malayalamMonth, day: result.calculatedValues.malayalamDay)
            ),
            row(
                id: "rahu",
                label: "Rahu Kalam",
                expected: result.expectedValues.rahuKalam.map { period($0, timeZone: timeZone) },
                calculated: result.calculatedValues.rahuKalam.map { period($0, timeZone: timeZone) },
                delta: result.delta.rahuKalamSeconds,
                tolerance: 120
            ),
            row(
                id: "yamagandam",
                label: "Yamagandam",
                expected: result.expectedValues.yamagandam.map { period($0, timeZone: timeZone) },
                calculated: result.calculatedValues.yamagandam.map { period($0, timeZone: timeZone) },
                delta: result.delta.yamagandamSeconds,
                tolerance: 120
            ),
            row(
                id: "gulika",
                label: "Gulika Kalam",
                expected: result.expectedValues.gulikaKalam.map { period($0, timeZone: timeZone) },
                calculated: result.calculatedValues.gulikaKalam.map { period($0, timeZone: timeZone) },
                delta: result.delta.gulikaKalamSeconds,
                tolerance: 120
            )
        ]
    }

    private static func row(id: String, label: String, expected: String?, calculated: String?, delta: TimeInterval?, tolerance: TimeInterval) -> ValidationReportRow {
        ValidationReportRow(
            id: id,
            label: label,
            expected: expected ?? "No fixture",
            calculated: calculated ?? "Unavailable",
            delta: delta.map(formatDelta) ?? "-",
            passed: delta.map { abs($0) <= tolerance }
        )
    }

    private static func valueRow(id: String, label: String, expected: String?, calculated: String?) -> ValidationReportRow {
        ValidationReportRow(
            id: id,
            label: label,
            expected: expected ?? "No fixture",
            calculated: calculated ?? "Unavailable",
            delta: "-",
            passed: expected.map { $0 == calculated }
        )
    }

    private static func malayalamDate(month: MalayalamMonth?, day: Int?) -> String? {
        guard let month, let day else { return nil }
        return "\(month.englishName) \(day)"
    }

    private static func period(_ period: TimePeriod, timeZone: TimeZone) -> String {
        "\(PanchangamFormatters.time(period.start, timeZone: timeZone)) - \(PanchangamFormatters.time(period.end, timeZone: timeZone))"
    }

    private static func formatDelta(_ delta: TimeInterval) -> String {
        let sign = delta >= 0 ? "+" : "-"
        let absolute = abs(Int(delta.rounded()))
        let minutes = absolute / 60
        let seconds = absolute % 60
        return "\(sign)\(minutes)m \(seconds)s"
    }
}
