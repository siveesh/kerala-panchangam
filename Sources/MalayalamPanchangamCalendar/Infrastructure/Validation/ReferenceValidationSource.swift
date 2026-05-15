import Foundation

protocol ReferenceValidationSource: Sendable {
    var sourceName: String { get }
    func expectedValues(for day: PanchangamDay) async -> ValidationValueSet?
}

struct HistoricalArchiveValidationSource: ReferenceValidationSource {
    let sourceName: String
    private let fixtures: [String: ValidationValueSet]

    init(sourceName: String = "Historical Malayalam Calendar Archive", fixtures: [String: ValidationValueSet] = [:]) {
        self.sourceName = sourceName
        self.fixtures = fixtures
    }

    init(fixtureURL: URL) throws {
        let loaded = try ValidationFixtureLoader.load(from: fixtureURL)
        self.sourceName = loaded.sourceName
        self.fixtures = loaded.fixtures
    }

    func expectedValues(for day: PanchangamDay) async -> ValidationValueSet? {
        fixtures[fixtureKey(for: day)]
    }

    private func fixtureKey(for day: PanchangamDay) -> String {
        "\(day.location.name.lowercased())|\(day.isoDateKey)"
    }
}

extension HistoricalArchiveValidationSource {
    static func thrissurFixture(_ dateKey: String, expected: ValidationValueSet) -> HistoricalArchiveValidationSource {
        HistoricalArchiveValidationSource(fixtures: ["thrissur|\(dateKey)": expected])
    }
}

struct OnlinePanchangamValidationSource: ReferenceValidationSource {
    let sourceName: String

    func expectedValues(for day: PanchangamDay) async -> ValidationValueSet? {
        // Online validation is intentionally optional so the app remains offline-first.
        nil
    }
}
