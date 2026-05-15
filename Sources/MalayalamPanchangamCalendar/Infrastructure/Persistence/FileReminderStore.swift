import Foundation
import OSLog

// MARK: - FileReminderStore

/// Encrypted persistent store for `MalayalamReminder` records.
///
/// Data is AES-256-GCM encrypted before writing using `KeychainEncryptionManager`.
/// Plaintext blobs written by earlier app versions are detected and upgraded
/// transparently on the first read.
actor FileReminderStore: ReminderStoring {

    private let fileURL: URL
    private let crypto = KeychainEncryptionManager.shared
    private static let logger = Logger(subsystem: "com.siveesh.calendar", category: "FileReminderStore")

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.fileURL = base
                .appending(path: "MalayalamPanchangamCalendar", directoryHint: .isDirectory)
                .appending(path: "Reminders.bin")       // .bin signals encrypted content
        }
    }

    // MARK: Load

    func loadReminders() async throws -> [MalayalamReminder] {
        // Check legacy .json path first (before checking .bin)
        let legacyURL = fileURL.deletingLastPathComponent()
            .appending(path: "Reminders.json")
        if FileManager.default.fileExists(atPath: legacyURL.path()),
           !FileManager.default.fileExists(atPath: fileURL.path()) {
            // Migrate legacy plaintext file
            Self.logger.notice("Migrating legacy Reminders.json → encrypted Reminders.bin")
            if let legacyData = try? Data(contentsOf: legacyURL),
               let reminders = try? JSONDecoder().decode([MalayalamReminder].self, from: legacyData) {
                try await saveReminders(reminders)       // writes encrypted .bin
                try? FileManager.default.removeItem(at: legacyURL)
                Self.logger.info("Legacy reminders migration complete (\(reminders.count) item(s))")
                return reminders
            }
        }

        guard FileManager.default.fileExists(atPath: fileURL.path()) else { return [] }
        let storedData = try Data(contentsOf: fileURL)

        // Migration path: plaintext blob (first-time upgrade)
        if crypto.looksLikePlaintext(storedData) {
            Self.logger.notice("Detected plaintext reminders file — migrating to encrypted storage")
            let reminders = try JSONDecoder().decode([MalayalamReminder].self, from: storedData)
            try await saveReminders(reminders)
            Self.logger.info("Plaintext → encrypted reminders migration complete (\(reminders.count) item(s))")
            return reminders
        }

        // Normal path: decrypt then decode
        do {
            let plaintext = try await crypto.decrypt(storedData)
            let reminders = try JSONDecoder().decode([MalayalamReminder].self, from: plaintext)
            Self.logger.debug("Loaded \(reminders.count) reminder(s) from encrypted store")
            return reminders
        } catch {
            Self.logger.error("Failed to decrypt or decode reminders: \(error, privacy: .public)")
            throw error
        }
    }

    // MARK: Save

    func saveReminders(_ reminders: [MalayalamReminder]) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let plaintext = try encoder.encode(reminders)

        let encrypted = try await crypto.encrypt(plaintext)
        try encrypted.write(to: fileURL, options: [.atomic])
        Self.logger.info("Saved \(reminders.count) reminder(s) to encrypted store (\(encrypted.count) bytes)")
    }
}
