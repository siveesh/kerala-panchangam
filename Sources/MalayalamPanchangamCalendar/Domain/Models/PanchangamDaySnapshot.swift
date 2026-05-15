import Foundation

struct PanchangamDaySnapshot: Codable, Hashable, Sendable {
    var gregorianDate: String
    var weekday: String
    var malayalamMonth: String
    var malayalamDay: String
    var kollavarshamYear: String
    var nakshatra: String
    var rahuKalam: String
    var locationName: String

    init(day: PanchangamDay, languagePreference: LanguagePreference = .bilingual) {
        let timeZone = day.location.timeZone
        gregorianDate = day.isoDateKey
        weekday = day.weekday
        malayalamMonth = switch languagePreference {
        case .english:
            day.malayalamMonth.englishName
        case .malayalam:
            day.malayalamMonth.malayalamName
        case .bilingual:
            "\(day.malayalamMonth.englishName) / \(day.malayalamMonth.malayalamName)"
        }
        malayalamDay = "\(day.malayalamDay)"
        kollavarshamYear = "\(day.kollavarshamYear)"
        nakshatra = switch languagePreference {
        case .english:
            day.mainNakshatra.englishName
        case .malayalam:
            day.mainNakshatra.malayalamName
        case .bilingual:
            "\(day.mainNakshatra.englishName) / \(day.mainNakshatra.malayalamName)"
        }
        rahuKalam = "\(PanchangamFormatters.time(day.rahuKalam.start, timeZone: timeZone)) - \(PanchangamFormatters.time(day.rahuKalam.end, timeZone: timeZone))"
        locationName = day.location.name
    }

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

    init(
        gregorianDate: String,
        weekday: String,
        malayalamMonth: String,
        malayalamDay: String,
        kollavarshamYear: String,
        nakshatra: String,
        rahuKalam: String,
        locationName: String
    ) {
        self.gregorianDate = gregorianDate
        self.weekday = weekday
        self.malayalamMonth = malayalamMonth
        self.malayalamDay = malayalamDay
        self.kollavarshamYear = kollavarshamYear
        self.nakshatra = nakshatra
        self.rahuKalam = rahuKalam
        self.locationName = locationName
    }
}
