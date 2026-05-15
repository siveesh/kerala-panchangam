import Foundation

// Mirror of the main app's Domain/Models/PanchangamDaySnapshot.
// Must stay schema-compatible — both encode/decode the same JSON file.

struct PanchangamDaySnapshot: Codable, Hashable {
    /// Human-readable date, e.g. "15 May 2026"
    var gregorianDate: String
    var weekday: String
    var malayalamMonth: String
    var malayalamDay: String
    var kollavarshamYear: String
    var nakshatra: String
    /// Tithi with paksha, e.g. "Shukla Navami / ശുക്ല നവമി"
    var tithi: String
    /// Formatted sunrise time in the location's timezone
    var sunrise: String
    var rahuKalam: String
    var locationName: String

    static let placeholder = PanchangamDaySnapshot(
        gregorianDate: "14 Apr 2026",
        weekday: "Tuesday",
        malayalamMonth: "Medam / മേടം",
        malayalamDay: "1",
        kollavarshamYear: "1202",
        nakshatra: "Uthrattathi / ഉത്രട്ടാതി",
        tithi: "Shukla Tritiya / ശുക്ല തൃതീയ",
        sunrise: "6:12 AM",
        rahuKalam: "3:29 PM – 5:02 PM",
        locationName: "Thrissur"
    )
}
