import Foundation

struct PanchangamDaySnapshot: Codable, Hashable {
    var gregorianDate: String
    var weekday: String
    var malayalamMonth: String
    var malayalamDay: String
    var kollavarshamYear: String
    var nakshatra: String
    var rahuKalam: String
    var locationName: String

    static let placeholder = PanchangamDaySnapshot(
        gregorianDate: "2026-04-14",
        weekday: "Tuesday",
        malayalamMonth: "Medam / മേടം",
        malayalamDay: "1",
        kollavarshamYear: "1201",
        nakshatra: "Uthrattathi / ഉത്രട്ടാതി",
        rahuKalam: "3:29 PM - 5:02 PM",
        locationName: "Thrissur"
    )
}
