import Foundation

actor FilePanchangamCache: PanchangamDayCaching {
    private let rootURL: URL

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.rootURL = base.appending(path: "MalayalamPanchangamCalendar/YearCache", directoryHint: .isDirectory)
        }
    }

    func cachedYear(year: Int, location: GeoLocation, mode: CalculationMode) async throws -> [PanchangamDay]? {
        let url = cacheURL(year: year, location: location, mode: mode)
        guard FileManager.default.fileExists(atPath: url.path()) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([PanchangamDay].self, from: data)
    }

    func saveYear(_ days: [PanchangamDay], year: Int, location: GeoLocation, mode: CalculationMode) async throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(days)
        try data.write(to: cacheURL(year: year, location: location, mode: mode), options: [.atomic])
    }

    private func cacheURL(year: Int, location: GeoLocation, mode: CalculationMode) -> URL {
        // Keep only alphanumerics and hyphens to prevent path-traversal or invalid filenames.
        let allowed = CharacterSet.alphanumerics.union(.init(charactersIn: "-"))
        let safeLocation = location.name
            .components(separatedBy: allowed.inverted)
            .joined(separator: "-")
            .trimmingCharacters(in: .init(charactersIn: "-"))
        let name = safeLocation.isEmpty ? "unknown" : safeLocation
        return rootURL.appending(path: "\(year)-\(name)-\(mode.rawValue).json")
    }
}
