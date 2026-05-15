import Foundation

struct PanchangamDaySnapshot: Codable, Hashable, Sendable {
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

    init(day: PanchangamDay, languagePreference: LanguagePreference = .bilingual) {
        let tz = day.location.timeZone

        // Format date as "15 May 2026" — readable in widget without abbreviation
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "d MMM yyyy"
        dateFmt.timeZone = tz
        gregorianDate = dateFmt.string(from: day.date)

        weekday = day.weekday

        malayalamMonth = switch languagePreference {
        case .english:   day.malayalamMonth.englishName
        case .malayalam: day.malayalamMonth.malayalamName
        case .bilingual: "\(day.malayalamMonth.englishName) / \(day.malayalamMonth.malayalamName)"
        }
        malayalamDay     = "\(day.malayalamDay)"
        kollavarshamYear = "\(day.kollavarshamYear)"

        nakshatra = switch languagePreference {
        case .english:   day.mainNakshatra.englishName
        case .malayalam: day.mainNakshatra.malayalamName
        case .bilingual: "\(day.mainNakshatra.englishName) / \(day.mainNakshatra.malayalamName)"
        }

        let paksha = Paksha.from(day.tithi)
        // Tithi has only englishName; paksha has both English and Malayalam
        let tithiEn = "\(paksha.englishName) \(day.tithi.englishName)"
        tithi = switch languagePreference {
        case .english:   tithiEn
        case .malayalam: "\(paksha.malayalamName) \(day.tithi.englishName)"
        case .bilingual: "\(tithiEn) / \(paksha.malayalamName) \(day.tithi.englishName)"
        }

        sunrise  = PanchangamFormatters.time(day.sunrise, timeZone: tz)
        rahuKalam = "\(PanchangamFormatters.time(day.rahuKalam.start, timeZone: tz)) – \(PanchangamFormatters.time(day.rahuKalam.end, timeZone: tz))"
        locationName = day.location.name
    }

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

    init(
        gregorianDate: String,
        weekday: String,
        malayalamMonth: String,
        malayalamDay: String,
        kollavarshamYear: String,
        nakshatra: String,
        tithi: String,
        sunrise: String,
        rahuKalam: String,
        locationName: String
    ) {
        self.gregorianDate   = gregorianDate
        self.weekday         = weekday
        self.malayalamMonth  = malayalamMonth
        self.malayalamDay    = malayalamDay
        self.kollavarshamYear = kollavarshamYear
        self.nakshatra       = nakshatra
        self.tithi           = tithi
        self.sunrise         = sunrise
        self.rahuKalam       = rahuKalam
        self.locationName    = locationName
    }
}
