import Foundation

enum KeralaHolidays {
    // Fixed gazetted holidays (month, day).
    // Vishu is astronomically the sun's entry into Medam; April 14 is the usual Gregorian approximation.
    private static let fixed: Set<Int32> = {
        var s = Set<Int32>()
        for (m, d): (Int, Int) in [
            (1, 1),   // New Year's Day
            (1, 14),  // Pongal / Makar Sankranti
            (1, 26),  // Republic Day
            (4, 14),  // Vishu (approximate)
            (5, 1),   // May Day / Labour Day
            (8, 15),  // Independence Day
            (10, 2),  // Gandhi Jayanti
            (11, 1),  // Kerala Piravi
            (12, 25), // Christmas
        ] {
            s.insert(Int32(m * 100 + d))
        }
        return s
    }()

    // Returns true if (month, day) is a fixed Kerala public holiday.
    static func isHoliday(month: Int, day: Int) -> Bool {
        fixed.contains(Int32(month * 100 + day))
    }

    // Parses the "yyyy-MM-dd" isoDateKey and checks holiday + Good Friday.
    static func isHoliday(isoDateKey: String, year: Int) -> Bool {
        guard isoDateKey.count == 10 else { return false }
        guard
            let m = Int(isoDateKey[isoDateKey.index(isoDateKey.startIndex, offsetBy: 5)..<isoDateKey.index(isoDateKey.startIndex, offsetBy: 7)]),
            let d = Int(isoDateKey[isoDateKey.index(isoDateKey.startIndex, offsetBy: 8)...])
        else { return false }
        if isHoliday(month: m, day: d) { return true }
        // Good Friday: two days before Easter Sunday (Anonymous Gregorian algorithm)
        let (em, ed) = easterDate(year: year)
        // Good Friday = Easter − 2 days
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        if let easter = cal.date(from: DateComponents(year: year, month: em, day: ed)),
           let gf = cal.date(byAdding: .day, value: -2, to: easter) {
            let gfm = cal.component(.month, from: gf)
            let gfd = cal.component(.day, from: gf)
            if m == gfm && d == gfd { return true }
        }
        return false
    }

    // Anonymous Gregorian algorithm for Easter Sunday. Returns (month, day).
    static func easterDate(year: Int) -> (month: Int, day: Int) {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return (month, day)
    }
}
