import Foundation

actor WidgetSnapshotStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.malayalampanchangam.calendar")
                ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = base
                .appending(path: "MalayalamPanchangamCalendar", directoryHint: .isDirectory)
                .appending(path: "WidgetDaySnapshot.json")
        }
    }

    func loadSnapshot() async throws -> PanchangamDaySnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PanchangamDaySnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: PanchangamDaySnapshot) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}
