import Foundation
import OSLog

// MARK: - FamilyStore

/// Persistent store for PersonProfile records.
///
/// ## Storage strategy (most-reliable-first)
/// 1. **UserDefaults (encrypted)** — primary.  The JSON blob is encrypted with
///    AES-256-GCM before writing and decrypted on read.  The key lives in the
///    macOS Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
/// 2. **Plaintext migration** — if the stored blob is still raw JSON (first
///    launch after upgrading), the store decodes it as-is and immediately
///    re-saves it in encrypted form.
/// 3. **Legacy file migration** — first launch after switching from the old
///    file-based store: import data into UserDefaults (encrypted).
///
/// All errors are logged via OSLog (visible in Console.app).
actor FamilyStore: FamilyStoring {

    private static let udKey  = "SiveeshCalendar.FamilyProfiles"
    private static let logger = Logger(subsystem: "com.siveesh.calendar", category: "FamilyStore")
    private static let legacyURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                    ?? FileManager.default.temporaryDirectory
        return base
            .appending(path: "MalayalamPanchangamCalendar", directoryHint: .isDirectory)
            .appending(path: "FamilyProfiles.json")
    }()

    private let crypto = KeychainEncryptionManager.shared

    // MARK: Load

    func loadProfiles() async throws -> [PersonProfile] {

        // ── 1. Try UserDefaults (primary, encrypted) ───────────────────────
        if let storedData = UserDefaults.standard.data(forKey: Self.udKey) {
            // Migration path A: detect and upgrade plaintext blobs
            if crypto.looksLikePlaintext(storedData) {
                Self.logger.notice("Found plaintext profile data in UserDefaults — migrating to encrypted storage")
                if let profiles = try? Self.decodeProfiles(from: storedData) {
                    try await saveProfiles(profiles)      // re-save encrypted
                    Self.logger.info("Plaintext → encrypted migration complete (\(profiles.count) profile(s))")
                    return profiles
                }
                // Plaintext was corrupt — fall through to legacy migration
            } else {
                // Normal path: decrypt then decode
                do {
                    let plaintext = try await crypto.decrypt(storedData)
                    let profiles  = try Self.decodeProfiles(from: plaintext)
                    Self.logger.info("Loaded \(profiles.count) profile(s) from encrypted UserDefaults")
                    return profiles
                } catch {
                    Self.logger.error("Encrypted UserDefaults decode failed: \(error, privacy: .public)")
                    // Fall through to legacy migration
                }
            }
        }

        // ── 2. Migrate from legacy file (first-time upgrade) ───────────────
        if FileManager.default.fileExists(atPath: Self.legacyURL.path()) {
            Self.logger.notice("Attempting legacy file migration from \(Self.legacyURL.path())")
            do {
                let fileData = try Data(contentsOf: Self.legacyURL)
                // Legacy file may be plaintext or encrypted; try both
                let profiles: [PersonProfile]
                if crypto.looksLikePlaintext(fileData) {
                    profiles = try Self.decodeProfiles(from: fileData)
                } else {
                    let plaintext = try await crypto.decrypt(fileData)
                    profiles      = try Self.decodeProfiles(from: plaintext)
                }
                Self.logger.info("Legacy migration: \(profiles.count) profile(s) — saving encrypted to UserDefaults")
                try await saveProfiles(profiles)
                return profiles
            } catch {
                Self.logger.error("Legacy file migration failed: \(error, privacy: .public)")
            }
        }

        Self.logger.info("No existing profiles found — returning empty list")
        return []
    }

    // MARK: Save

    func saveProfiles(_ profiles: [PersonProfile]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let plaintext = try encoder.encode(profiles)

        // Encrypt before persisting
        let encrypted = try await crypto.encrypt(plaintext)
        UserDefaults.standard.set(encrypted, forKey: Self.udKey)
        Self.logger.info("Saved \(profiles.count) profile(s) to UserDefaults (encrypted, \(encrypted.count) bytes)")

        // Keep an encrypted backup at the legacy path
        do {
            let dir = Self.legacyURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try encrypted.write(to: Self.legacyURL, options: [.atomic])
        } catch {
            // Non-fatal — UserDefaults is the source of truth
            Self.logger.warning("Backup file write failed (non-fatal): \(error, privacy: .public)")
        }
    }

    // MARK: Backup / Restore

    /// Returns a plain-JSON Data blob of all profiles — suitable for saving to a user-chosen file.
    /// The data is NOT encrypted so it can be restored even after a clean reinstall.
    func exportBackup() async throws -> Data {
        let profiles = try await loadProfiles()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(profiles)
    }

    /// Decodes profiles from a plain-JSON backup file and REPLACES all existing profiles.
    /// Throws if the data cannot be decoded as `[PersonProfile]`.
    func importBackup(_ data: Data) async throws -> [PersonProfile] {
        let profiles = try Self.decodeProfiles(from: data)
        try await saveProfiles(profiles)
        return profiles
    }

    // MARK: - Private helpers

    private static func decodeProfiles(from data: Data) throws -> [PersonProfile] {
        try decoder().decode([PersonProfile].self, from: data)
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let c = try decoder.singleValueContainer()
            // Accept both ISO-8601 strings (new format) and raw Double timestamps (old format)
            if let str = try? c.decode(String.self) {
                let iso = ISO8601DateFormatter()
                if let date = iso.date(from: str) { return date }
                throw DecodingError.dataCorruptedError(in: c,
                    debugDescription: "Cannot parse date string: \(str)")
            }
            let ts = try c.decode(Double.self)
            return Date(timeIntervalSinceReferenceDate: ts)
        }
        return d
    }
}
