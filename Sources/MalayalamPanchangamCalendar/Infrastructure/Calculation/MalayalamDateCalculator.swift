import Foundation

struct MalayalamDateCalculator: Sendable {
    // Sidereal mean solar motion: 360° / 365.25636 days (sidereal year)
    private let meanSiderealSolarMotionPerDay = 0.98560910

    func malayalamDate(for date: Date, siderealSunLongitude: Double, timeZone: TimeZone) throws -> (month: MalayalamMonth, day: Int, kollavarshamYear: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let year = calendar.component(.year, from: date)

        let normalized = siderealSunLongitude.normalizedDegrees
        let month = monthForSiderealSunLongitude(normalized)
        let degreesIntoSign = normalized.truncatingRemainder(dividingBy: 30)
        // Malayalam months span one zodiac sign (≤31 days); cap at 31 to avoid invalid day 32
        let day = max(1, min(31, Int(floor(degreesIntoSign / meanSiderealSolarMotionPerDay)) + 1))
        let kollavarsham = kollavarshamYear(gregorianYear: year, malayalamMonth: month)
        return (month, day, kollavarsham)
    }

    private func monthForSiderealSunLongitude(_ longitude: Double) -> MalayalamMonth {
        let normalized = longitude.normalizedDegrees
        let zodiacSignIndex = Int(floor(normalized / 30.0))
        let monthRawValue = ((zodiacSignIndex + 8) % 12) + 1
        return MalayalamMonth(rawValue: monthRawValue) ?? .chingam
    }

    private func kollavarshamYear(gregorianYear: Int, malayalamMonth: MalayalamMonth) -> Int {
        switch malayalamMonth {
        case .chingam, .kanni, .thulam, .vrischikam, .dhanu:
            gregorianYear - 824
        case .makaram, .kumbham, .meenam, .medam, .edavam, .mithunam, .karkidakam:
            gregorianYear - 825
        }
    }
}
