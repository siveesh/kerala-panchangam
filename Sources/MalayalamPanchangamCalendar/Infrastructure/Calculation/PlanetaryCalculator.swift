import Foundation

// MARK: - PlanetBody

enum PlanetBody {
    case sun, moon, mars, mercury, jupiter, venus, saturn, rahu, ketu
}

// MARK: - PlanetaryCalculator

/// Geocentric planetary longitude calculator using Keplerian orbital elements.
/// Based on Meeus "Astronomical Algorithms" Chapter 33 (low accuracy, ~0.5° for planets).
struct PlanetaryCalculator {

    // MARK: - Public API

    /// Returns the TROPICAL geocentric ecliptic longitude of the given body at JD.
    /// For Rahu/Ketu returns mean node positions.
    func tropicalGeocentricLongitude(of body: PlanetBody, julianDay jd: Double) -> Double {
        switch body {
        case .rahu:
            return rahuLongitude(jd: jd)
        case .ketu:
            return (rahuLongitude(jd: jd) + 180.0).normalizedDegrees
        case .moon:
            return moonLongitude(jd: jd)
        case .sun:
            return sunGeocentricLongitude(jd: jd)
        case .mercury:
            return keplerianGeocentricLongitude(planet: .mercury, jd: jd)
        case .venus:
            return keplerianGeocentricLongitude(planet: .venus, jd: jd)
        case .mars:
            return keplerianGeocentricLongitude(planet: .mars, jd: jd)
        case .jupiter:
            return keplerianGeocentricLongitude(planet: .jupiter, jd: jd)
        case .saturn:
            return keplerianGeocentricLongitude(planet: .saturn, jd: jd)
        }
    }

    /// Returns true if planet is in retrograde motion at the given JD.
    /// Computed by checking if geocentric longitude decreases over 24 hours.
    func isRetrograde(_ body: PlanetBody, julianDay jd: Double) -> Bool {
        let lon0 = tropicalGeocentricLongitude(of: body, julianDay: jd)
        let lon1 = tropicalGeocentricLongitude(of: body, julianDay: jd + 1.0)
        var diff = lon1 - lon0
        if diff > 180.0 { diff -= 360.0 }
        if diff < -180.0 { diff += 360.0 }
        return diff < 0.0
    }

    // MARK: - Internal: Julian Day helpers

    /// JD from Date
    static func julianDay(from date: Date) -> Double {
        return date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    // MARK: - Private: Rahu / Ketu

    private func rahuLongitude(jd: Double) -> Double {
        let T = (jd - 2451545.0) / 36525.0
        return (125.044522 - 1934.136268 * T).normalizedDegrees
    }

    // MARK: - Private: Moon

    /// Tropical geocentric Moon longitude using Meeus Ch.47 (top 30 terms, ±0.05° accuracy).
    /// Delaunay arguments: l=Moon anomaly, l'=Sun anomaly, F=arg latitude, D=elongation, Ω=node.
    private func moonLongitude(jd: Double) -> Double {
        let T  = (jd - 2_451_545.0) / 36_525.0
        let T2 = T * T
        let T3 = T2 * T
        let T4 = T3 * T

        // Fundamental arguments (degrees), Meeus Ch.47
        let Lp = (218.3164477
                  + 481_267.88123421 * T
                  -       0.0015786  * T2
                  +       T3 / 538_841.0
                  -       T4 / 65_194_000.0).normalizedDegrees // Moon mean longitude

        let l  = (134.9633964
                  + 477_198.8676313 * T
                  +       0.0089970 * T2
                  +       T3 / 69_699.0
                  -       T4 / 14_712_000.0).normalizedDegrees // Moon mean anomaly

        let lp = (357.5291092
                  +  35_999.0502909 * T
                  -       0.0001536 * T2
                  +       T3 / 24_490_000.0).normalizedDegrees // Sun mean anomaly

        let F  = ( 93.2720950
                  + 483_202.0175233 * T
                  -       0.0036539 * T2
                  -       T3 / 3_526_000.0
                  +       T4 / 863_310_000.0).normalizedDegrees // Arg of latitude

        let D  = (297.8501921
                  + 445_267.1114034 * T
                  -       0.0018819 * T2
                  +       T3 / 545_868.0
                  -       T4 / 113_065_000.0).normalizedDegrees // Mean elongation

        let Om = (125.0445479
                  -   1_934.1362608 * T
                  +       0.0020754 * T2
                  +       T3 / 467_441.0
                  -       T4 / 60_616_000.0).normalizedDegrees // Ascending node

        // Eccentricity correction factor
        let E  = 1.0 - 0.002516 * T - 0.0000074 * T2

        // Convert to radians
        func r(_ d: Double) -> Double { d * .pi / 180.0 }

        // Top 30 longitude terms from Meeus Table 47.A [D, M, M', F, coeff °]
        // E multiplier applied where M or M' exponent = 1 (±1→E, ±2→E²)
        let terms: [(Int, Int, Int, Int, Double)] = [
            // D   l'  l   F    coeff (°)
            ( 0,  0,  1,  0,   6.288774),
            ( 2,  0, -1,  0,   1.274027),
            ( 2,  0,  0,  0,   0.658314),
            ( 0,  0,  2,  0,   0.213618),
            ( 0,  1,  0,  0,  -0.185116),   // E
            ( 0,  0,  0,  2,  -0.114332),
            ( 2,  0, -2,  0,   0.058793),
            ( 2, -1, -1,  0,   0.057066),   // E
            ( 2,  0,  1,  0,   0.053322),
            ( 2, -1,  0,  0,   0.045758),   // E
            ( 0,  1, -1,  0,  -0.040923),   // E
            ( 1,  0,  0,  0,  -0.034720),
            ( 0,  1,  1,  0,  -0.030383),   // E
            ( 2,  0,  0, -2,   0.015327),
            ( 0,  0,  1,  2,  -0.012528),
            ( 0,  0,  1, -2,   0.010980),
            ( 4,  0, -1,  0,   0.010675),
            ( 0,  0,  3,  0,   0.010034),
            ( 4,  0, -2,  0,   0.008548),
            ( 2,  1, -1,  0,  -0.007888),   // E
            ( 2,  1,  0,  0,  -0.006766),   // E
            ( 1,  0, -1,  0,  -0.005163),
            ( 1,  1,  0,  0,   0.004987),   // E
            ( 2, -1,  1,  0,   0.004036),   // E
            ( 2,  0,  2,  0,   0.003994),
            ( 4,  0,  0,  0,   0.003861),
            ( 2,  0, -3,  0,   0.003665),
            ( 0,  1, -2,  0,  -0.002689),   // E
            ( 2,  0, -1,  2,  -0.002602),
            ( 2, -1, -2,  0,   0.002390),   // E
        ]

        var sigma: Double = 0.0
        for (dCoeff, lpCoeff, lCoeff, fCoeff, coeff) in terms {
            let angle = r(Double(dCoeff) * D
                        + Double(lpCoeff) * lp
                        + Double(lCoeff)  * l
                        + Double(fCoeff)  * F)
            let eMult: Double
            switch abs(lpCoeff) {
            case 1: eMult = E
            case 2: eMult = E * E
            default: eMult = 1.0
            }
            sigma += coeff * eMult * sin(angle)
        }

        // Additive terms from Meeus eq.47.1, p.338
        // A1 = 119.75° + 131.849°·T  (Venus perturbation on Moon anomaly)
        // A2 = 53.09°  + 479264.290°·T  (Jupiter perturbation)
        let A1 = (119.75 + 131.849    * T).normalizedDegrees
        let A2 = ( 53.09 + 479_264.290 * T).normalizedDegrees
        sigma += 0.003958 * sin(r(A1))
        sigma += 0.001962 * sin(r(Lp - F))
        sigma += 0.000318 * sin(r(A2))

        return (Lp + sigma).normalizedDegrees
    }

    // MARK: - Private: Sun

    private func sunGeocentricLongitude(jd: Double) -> Double {
        let (xe, ye) = earthHeliocentric(jd: jd)
        return atan2(-ye, -xe).radiansToDegrees.normalizedDegrees
    }

    // MARK: - Private: Keplerian planets

    private enum KeplerPlanet {
        case mercury, venus, earth, mars, jupiter, saturn
    }

    private struct OrbitalElements {
        let L0: Double   // mean longitude at J2000 (degrees)
        let L1: Double   // mean longitude rate (degrees / Julian century)
        let w0: Double   // longitude of perihelion at J2000 (degrees)
        let w1: Double   // longitude of perihelion rate (degrees / Julian century)
        let e0: Double   // eccentricity at J2000
        let e1: Double   // eccentricity rate (per Julian century)
        let a:  Double   // semi-major axis (AU)
    }

    private func elements(for planet: KeplerPlanet) -> OrbitalElements {
        switch planet {
        case .mercury:
            return OrbitalElements(L0: 252.250906, L1: 149472.6746358,
                                   w0:  77.456119, w1:    573.562,
                                   e0:   0.20563593, e1: -0.000059510,
                                   a:    0.38709927)
        case .venus:
            return OrbitalElements(L0: 181.979801, L1:  58517.8156760,
                                   w0: 131.563703, w1:    628.130,
                                   e0:   0.00677188, e1: -0.000047766,
                                   a:    0.72332102)
        case .earth:
            return OrbitalElements(L0: 100.464457, L1:  35999.372850,
                                   w0: 102.937348, w1:   1198.000,
                                   e0:   0.01671123, e1: -0.000004180,
                                   a:    1.00000261)
        case .mars:
            return OrbitalElements(L0: 355.433275, L1:  19140.2993313,
                                   w0: 336.040909, w1:   1560.000,
                                   e0:   0.09341233, e1:  0.000090484,
                                   a:    1.52371034)
        case .jupiter:
            return OrbitalElements(L0:  34.351519, L1:   3034.9056606,
                                   w0:  14.331207, w1:   1843.000,
                                   e0:   0.04849485, e1:  0.000163244,
                                   a:    5.20288700)
        case .saturn:
            return OrbitalElements(L0:  50.077444, L1:   1222.1137943,
                                   w0:  93.057209, w1:   1966.000,
                                   e0:   0.05550825, e1: -0.000346641,
                                   a:    9.53667594)
        }
    }

    /// Returns heliocentric (x, y) in AU for Earth at the given JD.
    private func earthHeliocentric(jd: Double) -> (Double, Double) {
        return heliocentricXY(planet: .earth, jd: jd)
    }

    /// Returns heliocentric (x, y) in the ecliptic plane for a Keplerian planet.
    private func heliocentricXY(planet: KeplerPlanet, jd: Double) -> (Double, Double) {
        let T = (jd - 2451545.0) / 36525.0
        let el = elements(for: planet)

        let L    = (el.L0 + el.L1 * T).normalizedDegrees
        let wBar = (el.w0 + el.w1 * T).normalizedDegrees
        let e    = el.e0 + el.e1 * T
        let M    = (L - wBar).normalizedDegrees
        let Mrad = M.degreesToRadians

        let E    = solveKepler(Mrad, eccentricity: e)

        let nu   = 2.0 * atan2(
            sqrt(1.0 + e) * sin(E / 2.0),
            sqrt(1.0 - e) * cos(E / 2.0)
        )
        let theta = (nu.radiansToDegrees + wBar).normalizedDegrees
        let r     = el.a * (1.0 - e * cos(E))

        let x = r * cos(theta.degreesToRadians)
        let y = r * sin(theta.degreesToRadians)
        return (x, y)
    }

    private func keplerPlanet(from body: PlanetBody) -> KeplerPlanet {
        switch body {
        case .mercury: return .mercury
        case .venus:   return .venus
        case .mars:    return .mars
        case .jupiter: return .jupiter
        case .saturn:  return .saturn
        default:
            fatalError("Not a Keplerian planet: \(body)")
        }
    }

    private func keplerianGeocentricLongitude(planet: PlanetBody, jd: Double) -> Double {
        let kp = keplerPlanet(from: planet)

        // First pass: uncorrected position
        let (xp, yp) = heliocentricXY(planet: kp, jd: jd)
        let (xe, ye) = earthHeliocentric(jd: jd)

        let xGeo0 = xp - xe
        let yGeo0 = yp - ye

        // Light-time correction (one iteration)
        let delta = sqrt(xGeo0 * xGeo0 + yGeo0 * yGeo0)
        let tau   = 0.0057755183 * delta  // days

        let (xpC, ypC) = heliocentricXY(planet: kp, jd: jd - tau)
        let xGeo = xpC - xe
        let yGeo = ypC - ye

        return atan2(yGeo, xGeo).radiansToDegrees.normalizedDegrees
    }

    // MARK: - Private: Kepler equation solver

    /// Solves Kepler's equation M = E - e*sin(E) by fixed-point iteration.
    /// - Parameters:
    ///   - M: Mean anomaly in RADIANS.
    ///   - e: Eccentricity.
    /// - Returns: Eccentric anomaly E in RADIANS.
    private func solveKepler(_ M: Double, eccentricity e: Double) -> Double {
        var E = M
        for _ in 0..<50 {
            E = M + e * sin(E)
        }
        return E
    }
}
