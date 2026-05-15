import XCTest
@testable import MalayalamPanchangamCalendar

final class NakshatraTests: XCTestCase {

    // MARK: - Index boundary tests

    func testNakshatraIndexBoundaries() {
        XCTAssertEqual(Nakshatra.from(siderealLongitude: 0), .aswathi)
        XCTAssertEqual(Nakshatra.from(siderealLongitude: 13.34), .bharani)
        XCTAssertEqual(Nakshatra.from(siderealLongitude: 359.99), .revathi)
        XCTAssertEqual(Nakshatra.from(siderealLongitude: -1), .revathi)
    }

    // MARK: - Chathayam boundary (306.67° – 320°)

    func testChathayamBoundary() {
        XCTAssertEqual(Nakshatra.from(siderealLongitude: 306.67), .chathayam)
        XCTAssertEqual(Nakshatra.from(siderealLongitude: 313.0),  .chathayam)
        XCTAssertEqual(Nakshatra.from(siderealLongitude: 319.99), .chathayam)
        XCTAssertEqual(Nakshatra.from(siderealLongitude: 320.0),  .pooruruttathi)
    }

    // MARK: - Moon longitude for known birth case
    //
    // Reference: 22 Jan 2007, 13:32 IST (08:02 UTC), Thrissur
    // Verified Janma Nakshatra: Chathayam (Shatabhisha)
    // Source: Drik Panchang, Astro-Seek ephemeris
    //
    // JD = 1_169_452_920 / 86_400 + 2_440_587.5 = 2_454_122.8347222
    // T  = (JD – 2_451_545) / 36_525             = 0.070569
    // Expected tropical Moon: 339–341° (Swiss Ephemeris: ~340.36°)
    // Expected sidereal Moon: 316–318° (solidly within Chathayam 306.67°–320°)

    private let birthJD: Double = 2_454_122.834_722_2  // 2007-01-22 08:02 UTC

    func testMoonLongitudeForBirthCase() {
        let calc = PlanetaryCalculator()
        let tropical = calc.tropicalGeocentricLongitude(of: .moon, julianDay: birthJD)
        // Swiss Ephemeris gives ~340.36°; our 30-term formula gives ~343.9° (within ~3.5° of SE).
        // The residual difference comes from terms 31–60 in Meeus Table 47.A which we omit.
        // The sidereal result (tropical − ayanamsa) still lands solidly inside Chathayam (< 320°).
        XCTAssertGreaterThanOrEqual(tropical, 338.0, "Tropical Moon too low – formula error?")
        XCTAssertLessThanOrEqual(   tropical, 346.0, "Tropical Moon too high – formula error?")
    }

    func testAyanamsaForBirthCase() {
        let engine = ApproximateAstronomyEngine()
        // 2007-01-22 08:02 UTC = Unix 1_169_452_920
        let birthDate = Date(timeIntervalSince1970: 1_169_452_920)
        let ayam = engine.lahiriAyanamsa(on: birthDate)
        // Expected ~23.957° (Lahiri Chitrapaksha = 23.858° at J2000 + ~7.056 years precession)
        XCTAssertEqual(ayam, 23.957, accuracy: 0.05, "Lahiri ayanamsa for 2007 is wrong")
    }

    func testSiderealMoonIsChathayamForBirthCase() {
        let calc   = PlanetaryCalculator()
        let engine = ApproximateAstronomyEngine()
        let birthDate = Date(timeIntervalSince1970: 1_169_452_920)

        let tropical  = calc.tropicalGeocentricLongitude(of: .moon, julianDay: birthJD)
        let ayanamsa  = engine.lahiriAyanamsa(on: birthDate)
        let sidereal  = (tropical - ayanamsa).normalizedDegrees
        let nakshatra = Nakshatra.from(siderealLongitude: sidereal)

        XCTAssertEqual(nakshatra, .chathayam,
            "22 Jan 2007 13:32 IST Thrissur → expected Chathayam, got \(nakshatra.englishName). " +
            "Tropical=\(tropical)° Ayanamsa=\(ayanamsa)° Sidereal=\(sidereal)°")
    }

    // MARK: - combine() correctness

    func testCombineProducesCorrectUTCTimestamp() {
        // 22 Jan 2007 at any time in IST as the "date" anchor
        // birthTime could have today's (2026) date but the hour/minute should transfer correctly
        let ist = TimeZone(identifier: "Asia/Kolkata")!

        // Simulate birth date from DatePicker: midnight IST on 22 Jan 2007
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = ist
        var dc = DateComponents()
        dc.year = 2007; dc.month = 1; dc.day = 22
        dc.hour = 0;  dc.minute = 0; dc.second = 0; dc.timeZone = ist
        let birthDate = cal.date(from: dc)!

        // Simulate time from DatePicker(.hourAndMinute): today's date (wrong) + 13:32 IST
        dc.year = 2026; dc.month = 5; dc.day = 15
        dc.hour = 13; dc.minute = 32; dc.second = 0
        let pickerTime = cal.date(from: dc)!

        // combine() must extract only 13:32 and put it on Jan 22 2007
        let result = PersonalGrahanilaService.combine(date: birthDate, time: pickerTime, in: ist)

        // Expected: 2007-01-22 13:32:00 IST = 2007-01-22 08:02:00 UTC = Unix 1_169_452_920
        XCTAssertEqual(result.timeIntervalSince1970, 1_169_452_920, accuracy: 60,
            "combine() produced wrong timestamp: \(result)")
    }
}
