import CoreLocation
import Foundation

actor AppleGeocodingService: LocationSearching {
    private let geocoder = CLGeocoder()

    func searchCity(_ query: String) async throws -> [GeoLocation] {
        let placemarks = try await geocoder.geocodeAddressString(query)
        let results = placemarks.compactMap { placemark -> GeoLocation? in
            guard let coordinate = placemark.location?.coordinate else { return nil }
            return GeoLocation(
                name: placemark.locality ?? placemark.name ?? query,
                state: placemark.administrativeArea ?? "",
                country: placemark.country ?? "",
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timezoneIdentifier: placemark.timeZone?.identifier ?? TimeZone.current.identifier,
                elevationMeters: placemark.location?.altitude
            )
        }

        if results.isEmpty {
            throw PanchangamError.geocodingFailed(query)
        }
        return results
    }

    func reverseGeocode(latitude: Double, longitude: Double) async throws -> GeoLocation {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        guard let p = placemarks.first else {
            throw PanchangamError.geocodingFailed("No placemark at \(latitude), \(longitude)")
        }
        let name = p.locality ?? p.name ?? "Unknown"
        let state = p.administrativeArea ?? ""
        let country = p.country ?? ""
        let tz = p.timeZone ?? .current
        return GeoLocation(
            name: name,
            state: state,
            country: country,
            latitude: latitude,
            longitude: longitude,
            timezoneIdentifier: tz.identifier,
            elevationMeters: nil
        )
    }
}
