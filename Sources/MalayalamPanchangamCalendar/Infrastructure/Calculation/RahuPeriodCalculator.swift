import Foundation

struct RahuPeriodCalculator: Sendable {
    // weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
    //
    // Part N starts at sunrise + (N-1) × (dayLength/8).
    // Values below are verified against published Kerala Panchangam fixtures:
    //   - 2026-01-01 Thrissur (Thursday, sunrise 06:42, partLen 86.25 min):
    //       Rahu 13:54 = part 6 ✓  Yamag 06:42 = part 1 ✓  Gulika 09:35 = part 3 ✓
    //   - 2026-04-14 Thrissur (Tuesday, sunrise 06:14, partLen 92.625 min):
    //       Rahu 15:29 = part 7 ✓  Yamag 09:19 = part 3 ✓  Gulika 12:24 = part 5 ✓
    //
    // Standard 6 AM–6 PM equivalent times:
    //   Rahu:       Sun 4:30 PM, Mon 7:30 AM, Tue 3 PM, Wed 12 PM, Thu 1:30 PM, Fri 10:30 AM, Sat 9 AM
    //   Yamagandam: Sun 12 PM,   Mon 10:30 AM, Tue 9 AM, Wed 7:30 AM, Thu 6 AM,  Fri 3 PM,    Sat 1:30 PM
    //   Gulika:     Sun 3 PM,    Mon 1:30 PM,  Tue 12 PM, Wed 10:30 AM, Thu 9 AM, Fri 7:30 AM, Sat 6 AM
    private let rahuPartByWeekday      = [1: 8, 2: 2, 3: 7, 4: 5, 5: 6, 6: 4, 7: 3]
    private let yamagandamPartByWeekday = [1: 5, 2: 4, 3: 3, 4: 2, 5: 1, 6: 7, 7: 6]
    private let gulikaPartByWeekday     = [1: 7, 2: 6, 3: 5, 4: 4, 5: 3, 6: 2, 7: 1]

    func periods(for date: Date, sunrise: Date, sunset: Date, timeZone: TimeZone) -> (rahu: TimePeriod, yamagandam: TimePeriod, gulika: TimePeriod) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: date)
        let partLength = sunset.timeIntervalSince(sunrise) / 8

        return (
            rahu: period(part: rahuPartByWeekday[weekday] ?? 1, sunrise: sunrise, partLength: partLength),
            yamagandam: period(part: yamagandamPartByWeekday[weekday] ?? 1, sunrise: sunrise, partLength: partLength),
            gulika: period(part: gulikaPartByWeekday[weekday] ?? 1, sunrise: sunrise, partLength: partLength)
        )
    }

    private func period(part: Int, sunrise: Date, partLength: TimeInterval) -> TimePeriod {
        let start = sunrise.addingTimeInterval(Double(part - 1) * partLength)
        return TimePeriod(start: start, end: start.addingTimeInterval(partLength))
    }
}
