import Foundation
import CryptoKit
import Security
import OSLog

// MARK: - EncryptionError

enum EncryptionError: Error, LocalizedError {
    case keychainReadFailed(OSStatus)
    case keychainWriteFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case sealFailed
    case openFailed
    case invalidCombinedData

    var errorDescription: String? {
        switch self {
        case .keychainReadFailed(let status):
            "Keychain read failed (OSStatus \(status)). The encryption key could not be retrieved."
        case .keychainWriteFailed(let status):
            "Keychain write failed (OSStatus \(status)). The encryption key could not be stored."
        case .keychainDeleteFailed(let status):
            "Keychain delete failed (OSStatus \(status))."
        case .sealFailed:
            "AES-GCM encryption failed."
        case .openFailed:
            "AES-GCM decryption failed. The data may be corrupt or the key has changed."
        case .invalidCombinedData:
            "The encrypted data is malformed (missing nonce or authentication tag)."
        }
    }
}

// MARK: - KeychainEncryptionManager

/// Manages a single AES-256-GCM key stored in the macOS Keychain.
///
/// Usage:
/// ```swift
/// let manager = KeychainEncryptionManager.shared
/// let encrypted = try manager.encrypt(plaintext)
/// let decrypted = try manager.decrypt(encrypted)
/// ```
///
/// The key is generated once on first use and persisted with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` so it is:
///   • Available whenever the Mac is unlocked
///   • Tied to this device — cannot migrate to iCloud Backup or another Mac
///   • Removed if the app is deleted (Keychain sandbox isolation)
actor KeychainEncryptionManager {

    // MARK: Singleton

    static let shared = KeychainEncryptionManager()

    // MARK: Keychain attributes

    private static let service = "com.siveesh.MalayalamPanchangamCalendar"
    private static let account = "PersonalDataEncryptionKey-v1"

    private static let logger = Logger(
        subsystem: "com.siveesh.calendar",
        category:  "KeychainEncryptionManager"
    )

    // MARK: Cached key (avoids repeated Keychain round-trips per session)

    private var cachedKey: SymmetricKey?

    // MARK: - Public API

    /// Encrypts `plaintext` using AES-256-GCM.
    /// Returns `nonce (12 B) + ciphertext + tag (16 B)` as a single `Data` blob.
    func encrypt(_ plaintext: Data) throws -> Data {
        let key = try getOrCreateKey()
        guard let sealed = try? AES.GCM.seal(plaintext, using: key),
              let combined = sealed.combined else {
            throw EncryptionError.sealFailed
        }
        return combined
    }

    /// Decrypts data produced by `encrypt(_:)`.
    /// Throws `EncryptionError.openFailed` if authentication fails (wrong key or tampered data).
    func decrypt(_ ciphertext: Data) throws -> Data {
        let key = try getOrCreateKey()
        do {
            let box = try AES.GCM.SealedBox(combined: ciphertext)
            return try AES.GCM.open(box, using: key)
        } catch {
            Self.logger.error("Decryption failed: \(error, privacy: .public)")
            throw EncryptionError.openFailed
        }
    }

    /// Checks whether `data` looks like it might be plaintext JSON rather than
    /// AES-GCM ciphertext (i.e., starts with `[` or `{`).
    /// Used for migration: if decryption fails on what appears to be plaintext, re-encrypt.
    nonisolated func looksLikePlaintext(_ data: Data) -> Bool {
        guard let first = data.first else { return false }
        return first == UInt8(ascii: "[") || first == UInt8(ascii: "{")
    }

    // MARK: - Key management

    private func getOrCreateKey() throws -> SymmetricKey {
        if let key = cachedKey { return key }
        if let existing = try retrieveKey() {
            cachedKey = existing
            return existing
        }
        let newKey = SymmetricKey(size: .bits256)
        try storeKey(newKey)
        cachedKey = newKey
        Self.logger.info("Generated new AES-256 encryption key and stored in Keychain")
        return newKey
    }

    private func retrieveKey() throws -> SymmetricKey? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            let key = SymmetricKey(data: data)
            Self.logger.debug("Retrieved encryption key from Keychain")
            return key
        case errSecItemNotFound:
            return nil
        default:
            Self.logger.error("Keychain read failed with OSStatus \(status)")
            throw EncryptionError.keychainReadFailed(status)
        }
    }

    private func storeKey(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let attributes: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     Self.service,
            kSecAttrAccount:     Self.account,
            kSecValueData:       keyData,
            // Available when Mac is unlocked; device-specific (not in iCloud Backup)
            kSecAttrAccessible:  kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        // Delete any stale entry first (no-op if absent)
        SecItemDelete([
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: Self.service,
            kSecAttrAccount: Self.account
        ] as CFDictionary)

        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            Self.logger.error("Keychain write failed with OSStatus \(status)")
            throw EncryptionError.keychainWriteFailed(status)
        }
    }
}
