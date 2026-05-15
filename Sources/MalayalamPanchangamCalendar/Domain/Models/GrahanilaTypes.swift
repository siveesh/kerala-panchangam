import Foundation

// MARK: - Planet

enum Planet: Int, CaseIterable, Identifiable, Sendable, Codable {
    case sun, moon, mars, mercury, jupiter, venus, saturn, rahu, ketu

    var id: Int { rawValue }

    var englishName: String {
        switch self {
        case .sun: "Sun"
        case .moon: "Moon"
        case .mars: "Mars"
        case .mercury: "Mercury"
        case .jupiter: "Jupiter"
        case .venus: "Venus"
        case .saturn: "Saturn"
        case .rahu: "Rahu"
        case .ketu: "Ketu"
        }
    }

    var malayalamName: String {
        switch self {
        case .sun: "സൂര്യൻ"
        case .moon: "ചന്ദ്രൻ"
        case .mars: "ചൊവ്വ"
        case .mercury: "ബുധൻ"
        case .jupiter: "വ്യാഴം"
        case .venus: "ശുക്രൻ"
        case .saturn: "ശനി"
        case .rahu: "രാഹു"
        case .ketu: "കേതു"
        }
    }

    var shortSymbol: String {
        switch self {
        case .sun: "ര"
        case .moon: "ച"
        case .mars: "കു"
        case .mercury: "ബു"
        case .jupiter: "ഗു"
        case .venus: "ശു"
        case .saturn: "ശ"
        case .rahu: "രാ"
        case .ketu: "കേ"
        }
    }

    var systemImage: String {
        switch self {
        case .sun: "sun.max.fill"
        case .moon: "moon.fill"
        case .mars: "flame.fill"
        case .mercury: "bubbles.and.sparkles"
        case .jupiter: "sparkles"
        case .venus: "heart.fill"
        case .saturn: "rings.layered.fill"
        case .rahu: "cursorarrow.rays"
        case .ketu: "arrow.uturn.backward"
        }
    }
}

// MARK: - Rasi

enum Rasi: Int, CaseIterable, Identifiable, Sendable, Codable {
    case medam = 0, edavam, mithunam, karkidakam, chingam, kanni, thulam, vrischikam, dhanu, makaram, kumbham, meenam

    var id: Int { rawValue }

    var englishName: String {
        switch self {
        case .medam: "Medam"
        case .edavam: "Edavam"
        case .mithunam: "Mithunam"
        case .karkidakam: "Karkidakam"
        case .chingam: "Chingam"
        case .kanni: "Kanni"
        case .thulam: "Thulam"
        case .vrischikam: "Vrischikam"
        case .dhanu: "Dhanu"
        case .makaram: "Makaram"
        case .kumbham: "Kumbham"
        case .meenam: "Meenam"
        }
    }

    var malayalamName: String {
        switch self {
        case .medam: "മേടം"
        case .edavam: "ഇടവം"
        case .mithunam: "മിഥുനം"
        case .karkidakam: "കർക്കടകം"
        case .chingam: "ചിങ്ങം"
        case .kanni: "കന്നി"
        case .thulam: "തുലാം"
        case .vrischikam: "വൃശ്ചികം"
        case .dhanu: "ധനു"
        case .makaram: "മകരം"
        case .kumbham: "കുംഭം"
        case .meenam: "മീനം"
        }
    }

    var zodiacSign: String {
        switch self {
        case .medam: "Aries"
        case .edavam: "Taurus"
        case .mithunam: "Gemini"
        case .karkidakam: "Cancer"
        case .chingam: "Leo"
        case .kanni: "Virgo"
        case .thulam: "Libra"
        case .vrischikam: "Scorpio"
        case .dhanu: "Sagittarius"
        case .makaram: "Capricorn"
        case .kumbham: "Aquarius"
        case .meenam: "Pisces"
        }
    }

    static func from(siderealLongitude: Double) -> Rasi {
        Rasi(rawValue: min(11, Int(floor(siderealLongitude.normalizedDegrees / 30.0)))) ?? .medam
    }
}

// MARK: - PlanetPosition

struct PlanetPosition: Sendable, Identifiable {
    let planet: Planet
    let tropicalLongitude: Double
    let siderealLongitude: Double
    let isRetrograde: Bool

    var id: Int { planet.rawValue }

    var rasi: Rasi {
        Rasi.from(siderealLongitude: siderealLongitude)
    }

    var degreeInRasi: Double {
        siderealLongitude.normalizedDegrees.truncatingRemainder(dividingBy: 30.0)
    }

    var nakshatra: Nakshatra {
        let normalized = siderealLongitude.normalizedDegrees
        let index = min(Int(floor(normalized / Nakshatra.spanDegrees)), 26)
        return Nakshatra(rawValue: index) ?? .aswathi
    }

    var pada: Int {
        let normalized = siderealLongitude.normalizedDegrees
        let degreeInNakshatra = normalized.truncatingRemainder(dividingBy: Nakshatra.spanDegrees)
        let raw = Int(floor(degreeInNakshatra / (Nakshatra.spanDegrees / 4))) + 1
        return min(max(raw, 1), 4)
    }
}

// MARK: - RasiHouse

struct RasiHouse: Sendable, Identifiable {
    let rasi: Rasi
    let planets: [PlanetPosition]

    var id: Int { rasi.rawValue }

    static func empty(rasi: Rasi) -> RasiHouse {
        RasiHouse(rasi: rasi, planets: [])
    }
}

// MARK: - GrahanilaChart

struct GrahanilaChart: Sendable {
    let date: Date
    let location: GeoLocation
    let calculationTime: Date
    let ayanamsa: AyanamsaSelection
    let houses: [RasiHouse]
    let planetPositions: [PlanetPosition]

    func house(for rasi: Rasi) -> RasiHouse {
        houses[rasi.rawValue]
    }
}

// MARK: - GrahanilaTimeOption

enum GrahanilaTimeOption: String, CaseIterable, Identifiable, Sendable {
    case sunrise, noon, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunrise: "At Sunrise"
        case .noon: "At Noon"
        case .custom: "Custom Time"
        }
    }

    var systemImage: String {
        switch self {
        case .sunrise: "sunrise.fill"
        case .noon: "sun.max.fill"
        case .custom: "clock.fill"
        }
    }
}
