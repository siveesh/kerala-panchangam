import Foundation

struct ValidationFixtureDocument: Codable, Sendable {
    var sourceName: String
    var timezoneIdentifier: String
    var rows: [ValidationFixtureRow]
}

struct ValidationFixtureRow: Codable, Sendable {
    var locationName: String
    var date: String
    var sunrise: String?
    var sunset: String?
    var nakshatra: String?
    var nakshatraTransition: String?
    var malayalamMonth: String?
    var malayalamDay: Int?
    var rahuKalam: TimeRangeFixture?
    var yamagandam: TimeRangeFixture?
    var gulikaKalam: TimeRangeFixture?
    var notes: String?
}

struct TimeRangeFixture: Codable, Sendable {
    var start: String
    var end: String
}

enum ValidationFixtureLoader {
    static func load(from url: URL) throws -> (sourceName: String, fixtures: [String: ValidationValueSet]) {
        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(ValidationFixtureDocument.self, from: data)
        return try load(document: document)
    }

    static func load(document: ValidationFixtureDocument) throws -> (sourceName: String, fixtures: [String: ValidationValueSet]) {
        guard let timeZone = TimeZone(identifier: document.timezoneIdentifier) else {
            throw PanchangamError.calculationUnavailable("Invalid fixture timezone: \(document.timezoneIdentifier)")
        }

        var fixtures: [String: ValidationValueSet] = [:]
        for row in document.rows {
            let key = "\(row.locationName.lowercased())|\(row.date)"
            fixtures[key] = try valueSet(from: row, timeZone: timeZone)
        }
        return (document.sourceName, fixtures)
    }

    private static func valueSet(from row: ValidationFixtureRow, timeZone: TimeZone) throws -> ValidationValueSet {
        ValidationValueSet(
            sunrise: try parseTime(row.sunrise, on: row.date, timeZone: timeZone),
            sunset: try parseTime(row.sunset, on: row.date, timeZone: timeZone),
            nakshatra: try parseNakshatra(row.nakshatra),
            nakshatraTransition: try parseTime(row.nakshatraTransition, on: row.date, timeZone: timeZone),
            malayalamMonth: try parseMalayalamMonth(row.malayalamMonth),
            malayalamDay: row.malayalamDay,
            rahuKalam: try parseRange(row.rahuKalam, on: row.date, timeZone: timeZone),
            yamagandam: try parseRange(row.yamagandam, on: row.date, timeZone: timeZone),
            gulikaKalam: try parseRange(row.gulikaKalam, on: row.date, timeZone: timeZone)
        )
    }

    private static func parseRange(_ range: TimeRangeFixture?, on date: String, timeZone: TimeZone) throws -> TimePeriod? {
        guard let range else { return nil }
        guard
            let start = try parseTime(range.start, on: date, timeZone: timeZone),
            let end = try parseTime(range.end, on: date, timeZone: timeZone)
        else {
            return nil
        }
        return TimePeriod(start: start, end: end)
    }

    private static func parseTime(_ time: String?, on date: String, timeZone: TimeZone) throws -> Date? {
        guard let time, !time.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let parsed = formatter.date(from: "\(date) \(time)") else {
            throw PanchangamError.calculationUnavailable("Invalid fixture time \(time) for \(date). Expected HH:mm.")
        }
        return parsed
    }

    private static func parseNakshatra(_ value: String?) throws -> Nakshatra? {
        guard let value else { return nil }
        if let nakshatra = Nakshatra.allCases.first(where: { String(describing: $0) == value }) {
            return nakshatra
        }
        throw PanchangamError.calculationUnavailable("Invalid fixture nakshatra: \(value).")
    }

    private static func parseMalayalamMonth(_ value: String?) throws -> MalayalamMonth? {
        guard let value else { return nil }
        if let month = MalayalamMonth.allCases.first(where: { String(describing: $0) == value }) {
            return month
        }
        throw PanchangamError.calculationUnavailable("Invalid fixture Malayalam month: \(value).")
    }
}
