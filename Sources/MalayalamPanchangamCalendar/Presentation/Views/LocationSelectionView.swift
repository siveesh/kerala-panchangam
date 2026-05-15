import MapKit
import SwiftUI

struct LocationSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedLocation: GeoLocation
    @State private var locationSearch = LocationSearchViewModel()
    @State private var mapCameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 10.5265, longitude: 76.2144),
            latitudinalMeters: 500_000,
            longitudinalMeters: 500_000
        )
    )

    var body: some View {
        TabView {
            presetView
                .tabItem { Label("Presets", systemImage: "list.bullet") }
            searchView
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            manualView
                .tabItem { Label("Coordinates", systemImage: "mappin.and.ellipse") }
            mapView
                .tabItem { Label("Map", systemImage: "map") }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 420)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
            }
        }
    }

    private var presetView: some View {
        List {
            Section("Kerala Districts") {
                ForEach(GeoLocation.keralaDistricts) { location in
                    locationButton(location)
                }
            }
            Section("Major Indian Cities") {
                ForEach(GeoLocation.majorIndianCities) { location in
                    locationButton(location)
                }
            }
            Section("Middle East & International") {
                ForEach(GeoLocation.internationalCities) { location in
                    locationButton(location)
                }
            }
        }
    }

    private var searchView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TextField("Search city", text: $locationSearch.query)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { Task { await locationSearch.search() } }
                Button {
                    Task { await locationSearch.search() }
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
            }

            if locationSearch.isSearching {
                ProgressView()
            }

            if let errorMessage = locationSearch.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            List(locationSearch.results) { location in
                locationButton(location)
            }
        }
    }

    private var manualView: some View {
        Form {
            TextField("Name", text: $locationSearch.manualName)
            TextField("State", text: $locationSearch.manualState)
            TextField("Country", text: $locationSearch.manualCountry)
            TextField("Latitude", text: $locationSearch.manualLatitude)
            TextField("Longitude", text: $locationSearch.manualLongitude)
            TextField("Timezone", text: $locationSearch.manualTimezoneIdentifier)

            if let errorMessage = locationSearch.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }

            Button {
                if let location = locationSearch.manualLocation() {
                    selectedLocation = location
                    dismiss()
                }
            } label: {
                Label("Use Coordinates", systemImage: "checkmark.circle")
            }
        }
    }

    private var mapView: some View {
        VStack(spacing: 12) {
            MapReader { proxy in
                Map(position: $mapCameraPosition) {
                    if let coord = locationSearch.pendingMapCoordinate {
                        Marker("Selected", coordinate: coord)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture { screenPoint in
                    if let coord = proxy.convert(screenPoint, from: .local) {
                        Task { await locationSearch.reverseGeocode(latitude: coord.latitude, longitude: coord.longitude) }
                    }
                }
            }

            if locationSearch.isReverseGeocoding {
                ProgressView("Finding location…")
            } else if let loc = locationSearch.pendingMapLocation {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(loc.name), \(loc.state)")
                        .font(.subheadline.weight(.medium))
                    Text("\(loc.latitude, specifier: "%.4f")°N, \(loc.longitude, specifier: "%.4f")°E")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Use This Location") {
                    selectedLocation = loc
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Tap on the map to pick a location")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func locationButton(_ location: GeoLocation) -> some View {
        Button {
            selectedLocation = location
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                    Text("\(location.state), \(location.country)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if location == selectedLocation {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
