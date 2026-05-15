import Foundation

struct ValidationValueSet: Codable, Hashable, Sendable {
    var sunrise: Date?
    var sunset: Date?
    var nakshatra: Nakshatra?
    var nakshatraTransition: Date?
    var malayalamMonth: MalayalamMonth?
    var malayalamDay: Int?
    var rahuKalam: TimePeriod?
    var yamagandam: TimePeriod?
    var gulikaKalam: TimePeriod?
}

struct ValidationDelta: Codable, Hashable, Sendable {
    var sunriseSeconds: TimeInterval?
    var sunsetSeconds: TimeInterval?
    var nakshatraTransitionSeconds: TimeInterval?
    var rahuKalamSeconds: TimeInterval?
    var yamagandamSeconds: TimeInterval?
    var gulikaKalamSeconds: TimeInterval?
}

struct ValidationResult: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var sourceName: String
    var expectedValues: ValidationValueSet
    var calculatedValues: ValidationValueSet
    var delta: ValidationDelta
    var passed: Bool
    var confidenceScore: Double
    var notes: String

    init(
        id: UUID = UUID(),
        sourceName: String,
        expectedValues: ValidationValueSet,
        calculatedValues: ValidationValueSet,
        delta: ValidationDelta,
        passed: Bool,
        confidenceScore: Double,
        notes: String = ""
    ) {
        self.id = id
        self.sourceName = sourceName
        self.expectedValues = expectedValues
        self.calculatedValues = calculatedValues
        self.delta = delta
        self.passed = passed
        self.confidenceScore = confidenceScore
        self.notes = notes
    }
}
