import CoreLocation
import Foundation
import Observation

@MainActor
@Observable
final class LocationSearchViewModel {
    var query = ""
    var results: [GeoLocation] = []
    var manualName = ""
    var manualState = ""
    var manualCountry = "India"
    var manualLatitude = ""
    var manualLongitude = ""
    var manualTimezoneIdentifier = "Asia/Kolkata"
    var isSearching = false
    var errorMessage: String?
    var pendingMapCoordinate: CLLocationCoordinate2D?
    var pendingMapLocation: GeoLocation?
    var isReverseGeocoding = false

    private let searchService: LocationSearching

    init(searchService: LocationSearching = AppleGeocodingService()) {
        self.searchService = searchService
    }

    func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            results = try await searchService.searchCity(trimmed)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reverseGeocode(latitude: Double, longitude: Double) async {
        isReverseGeocoding = true
        defer { isReverseGeocoding = false }
        pendingMapLocation = nil
        do {
            pendingMapLocation = try await searchService.reverseGeocode(latitude: latitude, longitude: longitude)
            pendingMapCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } catch {
            errorMessage = "Could not identify location: \(error.localizedDescription)"
        }
    }

    func manualLocation() -> GeoLocation? {
        guard
            let latitude = Double(manualLatitude),
            let longitude = Double(manualLongitude),
            (-90...90).contains(latitude),
            (-180...180).contains(longitude),
            TimeZone(identifier: manualTimezoneIdentifier) != nil
        else {
            errorMessage = "Enter valid latitude, longitude, and timezone."
            return nil
        }

        let name = manualName.trimmingCharacters(in: .whitespacesAndNewlines)
        return GeoLocation(
            name: name.isEmpty ? "Manual Location" : name,
            state: manualState,
            country: manualCountry,
            latitude: latitude,
            longitude: longitude,
            timezoneIdentifier: manualTimezoneIdentifier,
            elevationMeters: nil
        )
    }
}
