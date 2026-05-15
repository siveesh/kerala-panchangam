import Foundation

struct NakshatraPeriod: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    let nakshatra: Nakshatra
    let start: Date
    let end: Date

    init(id: UUID = UUID(), nakshatra: Nakshatra, start: Date, end: Date) {
        self.id = id
        self.nakshatra = nakshatra
        self.start = start
        self.end = end
    }

    var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }
}

struct TimePeriod: Codable, Hashable, Sendable {
    let start: Date
    let end: Date
}

struct AstronomicalData: Codable, Hashable, Sendable {
    let sunLongitude: Double
    let moonLongitude: Double
    let siderealSunLongitude: Double
    let siderealMoonLongitude: Double
    let lahiriAyanamsa: Double
}

struct PanchangamDay: Codable, Hashable, Identifiable, Sendable {
    var id: String { isoDateKey }

    let date: Date
    let isoDateKey: String
    let location: GeoLocation
    let calculationMode: CalculationMode
    let malayalamMonth: MalayalamMonth
    let malayalamDay: Int
    let kollavarshamYear: Int
    let weekday: String
    let sunrise: Date
    let sunset: Date
    let mainNakshatra: Nakshatra
    let sunriseNakshatra: Nakshatra
    let tithi: Tithi
    let nextNakshatra: Nakshatra?
    let nakshatraTransition: Date?
    let nakshatraPeriods: [NakshatraPeriod]
    let rahuKalam: TimePeriod
    let yamagandam: TimePeriod
    let gulikaKalam: TimePeriod
    let astronomicalData: AstronomicalData
}
