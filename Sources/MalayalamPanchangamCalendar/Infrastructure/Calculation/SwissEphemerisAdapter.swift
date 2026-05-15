import Foundation

struct SwissEphemerisAdapter: AstronomicalComputing {
    func tropicalSunLongitude(on date: Date) -> Double {
        assertionFailure("Swiss Ephemeris not integrated. Use ApproximateAstronomyEngine.")
        return 0
    }

    func tropicalMoonLongitude(on date: Date) -> Double {
        assertionFailure("Swiss Ephemeris not integrated. Use ApproximateAstronomyEngine.")
        return 0
    }

    func lahiriAyanamsa(on date: Date) -> Double {
        assertionFailure("Swiss Ephemeris not integrated. Use ApproximateAstronomyEngine.")
        return 0
    }

    func solarDay(for date: Date, location: GeoLocation) throws -> SolarDay {
        throw PanchangamError.calculationUnavailable("Swiss Ephemeris is not bundled yet. Select the approximate engine in Settings.")
    }
}
