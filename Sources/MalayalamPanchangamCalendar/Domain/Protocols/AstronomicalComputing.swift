import Foundation

struct SolarDay: Hashable, Sendable {
    let sunrise: Date
    let sunset: Date
}

protocol AstronomicalComputing: Sendable {
    func tropicalSunLongitude(on date: Date) -> Double
    func tropicalMoonLongitude(on date: Date) -> Double
    func lahiriAyanamsa(on date: Date) -> Double
    func solarDay(for date: Date, location: GeoLocation) throws -> SolarDay
}
