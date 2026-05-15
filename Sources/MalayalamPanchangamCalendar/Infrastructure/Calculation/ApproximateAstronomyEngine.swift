import Foundation

struct ApproximateAstronomyEngine: AstronomicalComputing {
    func tropicalSunLongitude(on date: Date) -> Double {
        let days = julianDaysSinceJ2000(date)
        let meanLongitude = 280.46646 + 0.98564736 * days
        let meanAnomaly = (357.52911 + 0.98560028 * days).normalizedDegrees
        let correction = 1.914602 * sin(meanAnomaly.degreesToRadians)
            + 0.019993 * sin((2 * meanAnomaly).degreesToRadians)
        return (meanLongitude + correction).normalizedDegrees
    }

    func tropicalMoonLongitude(on date: Date) -> Double {
        // Delegate to the authoritative 30-term Meeus Ch.47 implementation in PlanetaryCalculator
        let jd = PlanetaryCalculator.julianDay(from: date)
        return PlanetaryCalculator().tropicalGeocentricLongitude(of: .moon, julianDay: jd)
    }

    func lahiriAyanamsa(on date: Date) -> Double {
        let tropicalYear = 365.2422
        let yearsSinceJ2000 = julianDaysSinceJ2000(date) / tropicalYear
        // Lahiri Chitrapaksha ayanamsa as published in Indian almanacs (Drik Panchang compatible).
        // Derived from: B1900.0 value = 22°27′39.4″ = 22.460944°; rate = 50.290966″/year;
        // B1900.0 → J2000.0 = exactly 100 Julian years →
        //   J2000.0 base = 22.460944 + 100 × (50.290966 / 3600) = 23.857915°
        // The previous value 23.1898° was an IAU sidereal equinox reference unrelated to
        // traditional Indian almanac usage, and shifted sidereal longitudes ~0.668° too low.
        return 23.857915 + (50.290966 / 3600.0) * yearsSinceJ2000
    }

    func solarDay(for date: Date, location: GeoLocation) throws -> SolarDay {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = location.timeZone
        let localMidnight = calendar.startOfDay(for: date)

        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: localMidnight) ?? 1)
        let timezoneHours = Double(location.timeZone.secondsFromGMT(for: localMidnight)) / 3_600
        let gamma = 2.0 * Double.pi / 365.0 * (dayOfYear - 1)
        let equationOfTime = 229.18 * (
            0.000075
                + 0.001868 * cos(gamma)
                - 0.032077 * sin(gamma)
                - 0.014615 * cos(2 * gamma)
                - 0.040849 * sin(2 * gamma)
        )
        let solarDeclination = 0.006918
            - 0.399912 * cos(gamma)
            + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma)
            + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma)
            + 0.00148 * sin(3 * gamma)

        let zenith = 90.833.degreesToRadians
        let latitude = location.latitude.degreesToRadians
        let hourAngle = acos(
            ((cos(zenith) / (cos(latitude) * cos(solarDeclination))) - tan(latitude) * tan(solarDeclination))
                .clamped(to: -1...1)
        )
        let hourAngleDegrees = hourAngle.radiansToDegrees
        let solarNoonMinutes = 720 - 4 * location.longitude - equationOfTime + timezoneHours * 60
        let sunriseMinutes = solarNoonMinutes - 4 * hourAngleDegrees
        let sunsetMinutes = solarNoonMinutes + 4 * hourAngleDegrees

        return SolarDay(
            sunrise: localMidnight.addingTimeInterval(sunriseMinutes * 60),
            sunset: localMidnight.addingTimeInterval(sunsetMinutes * 60)
        )
    }

    private func julianDaysSinceJ2000(_ date: Date) -> Double {
        date.timeIntervalSince(Date(timeIntervalSince1970: 946_728_000)) / 86_400
    }
}
