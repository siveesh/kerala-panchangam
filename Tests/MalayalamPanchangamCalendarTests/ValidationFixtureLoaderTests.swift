import XCTest
@testable import MalayalamPanchangamCalendar

final class ValidationFixtureLoaderTests: XCTestCase {
    func testLoadsSampleFixtureDocument() throws {
        let url = try sampleFixtureURL()
        let loaded = try ValidationFixtureLoader.load(from: url)

        XCTAssertEqual(loaded.sourceName, "Historical Malayalam Calendar Archive - Thrissur Sample")
        XCTAssertNotNil(loaded.fixtures["thrissur|2026-01-01"])
        XCTAssertNotNil(loaded.fixtures["thrissur|2026-04-14"])
        XCTAssertEqual(loaded.fixtures["thrissur|2026-04-14"]?.malayalamMonth, .medam)
        XCTAssertEqual(loaded.fixtures["thrissur|2026-04-14"]?.nakshatra, .uthrattathi)
    }

    func testHistoricalSourceUsesLoadedFixtureFile() async throws {
        let url = try sampleFixtureURL()
        let source = try HistoricalArchiveValidationSource(fixtureURL: url)
        let day = try fixtureComparableDay()

        let expected = await source.expectedValues(for: day)

        XCTAssertEqual(source.sourceName, "Historical Malayalam Calendar Archive - Thrissur Sample")
        XCTAssertEqual(expected?.malayalamDay, 1)
        XCTAssertEqual(expected?.malayalamMonth, .medam)
    }

    func testValidatorFailsWhenFixtureDiffersFromCalculatedDay() async throws {
        let url = try sampleFixtureURL()
        let source = try HistoricalArchiveValidationSource(fixtureURL: url)
        let validator = DefaultPanchangamValidator(sources: [source])
        let day = try fixtureComparableDay()

        let result = await validator.validate(day: day)

        XCTAssertFalse(result.passed)
        XCTAssertEqual(result.sourceName, "Historical Malayalam Calendar Archive - Thrissur Sample")
        XCTAssertEqual(result.confidenceScore, 0.55)
    }

    private func sampleFixtureURL() throws -> URL {
        let root = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return root
            .appending(path: "Data")
            .appending(path: "ValidationFixtures")
            .appending(path: "thrissur-sample.json")
    }

    private func fixtureComparableDay() throws -> PanchangamDay {
        let location = GeoLocation.thrissur
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        let date = try XCTUnwrap(calendar.date(from: DateComponents(timeZone: location.timeZone, year: 2026, month: 4, day: 14)))
        let sunrise = try XCTUnwrap(calendar.date(from: DateComponents(timeZone: location.timeZone, year: 2026, month: 4, day: 14, hour: 6, minute: 20)))
        let sunset = try XCTUnwrap(calendar.date(from: DateComponents(timeZone: location.timeZone, year: 2026, month: 4, day: 14, hour: 18, minute: 40)))
        return PanchangamDay(
            date: date,
            isoDateKey: "2026-04-14",
            location: location,
            calculationMode: .keralaTraditional,
            malayalamMonth: .medam,
            malayalamDay: 1,
            kollavarshamYear: 1201,
            weekday: "Tuesday",
            sunrise: sunrise,
            sunset: sunset,
            mainNakshatra: .uthrattathi,
            sunriseNakshatra: .uthrattathi,
            tithi: .trayodashiKrishna,
            nextNakshatra: .revathi,
            nakshatraTransition: nil,
            nakshatraPeriods: [NakshatraPeriod(nakshatra: .uthrattathi, start: sunrise, end: sunset)],
            rahuKalam: TimePeriod(start: sunrise, end: sunrise.addingTimeInterval(90 * 60)),
            yamagandam: TimePeriod(start: sunrise, end: sunrise.addingTimeInterval(90 * 60)),
            gulikaKalam: TimePeriod(start: sunrise, end: sunrise.addingTimeInterval(90 * 60)),
            astronomicalData: AstronomicalData(
                sunLongitude: 24,
                moonLongitude: 180,
                siderealSunLongitude: 0,
                siderealMoonLongitude: 156,
                lahiriAyanamsa: 24
            )
        )
    }
}
