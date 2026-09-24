import CryptoKit
import Foundation
import Security

actor AuthenticationService {
    static let shared = AuthenticationService()

    struct Session: Codable, Equatable {
        let token: String
        let expiresAt: Int
        let licenseFingerprint: String
        let response: ClientAuthenticationResponse

        var isReusable: Bool { expiresAt > Int(Date().timeIntervalSince1970) + 60 }
    }

    private let keychainService = "com.apple.mobile.MobileHouseArrest.client-session.v1"
    private let keychainAccount = "current"
    private var cachedSession: Session?
    private var inFlight: Task<Session, Error>?

    func authenticate(licenseKey: String, force: Bool = false) async throws -> Session {
        let normalized = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { throw ClientAPIError.licenseInvalid("Hãy nhập Server Key.") }
        let fingerprint = Self.sha256(normalized)
        if !force, let session = reusableSession(fingerprint: fingerprint) { return session }
        if let inFlight { return try await inFlight.value }

        let task = Task<Session, Error> {
            let environment = DeviceEnvironment.current
            let identity = DeviceIdentityProvider.shared
            let timestamp = Int(Date().timeIntervalSince1970)
            let request = ClientAuthenticationRequest(
                licenseKey: normalized,
                deviceId: try await identity.deviceID(),
                devicePublicKey: try await identity.publicKey(),
                iosVersion: environment.versionString,
                iosBuild: environment.build,
                deviceModel: environment.modelIdentifier,
                architecture: environment.architecture.rawValue,
                appVersion: environment.appVersion,
                appBuild: environment.appBuild,
                timestamp: timestamp,
                nonce: Self.nonce()
            )
            let response: ClientAuthenticationResponse = try await APIClient.shared.sendSigned(
                path: "/api/v1/license/verify",
                body: request
            )
            guard response.success, response.device.authorized else {
                throw ClientAPIError.licenseInvalid("Key không hợp lệ.")
            }
            return Session(
                token: response.session,
                expiresAt: response.sessionExpiresAt,
                licenseFingerprint: fingerprint,
                response: response
            )
        }
        inFlight = task
        do {
            let session = try await task.value
            inFlight = nil
            cachedSession = session
            try store(session)
            return session
        } catch {
            inFlight = nil
            throw error
        }
    }

    func currentSession(licenseKey: String) -> Session? {
        reusableSession(fingerprint: Self.sha256(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()))
    }

    func clearSession() {
        inFlight?.cancel()
        inFlight = nil
        cachedSession = nil
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func reusableSession(fingerprint: String) -> Session? {
        if let cachedSession, cachedSession.licenseFingerprint == fingerprint, cachedSession.isReusable {
            return cachedSession
        }
        guard let stored = load(), stored.licenseFingerprint == fingerprint, stored.isReusable else { return nil }
        cachedSession = stored
        return stored
    }

    private func load() -> Session? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    private func store(_ session: Session) throws {
        let data = try JSONEncoder().encode(session)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let result = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if result == errSecItemNotFound {
            var insert = base
            attributes.forEach { insert[$0.key] = $0.value }
            guard SecItemAdd(insert as CFDictionary, nil) == errSecSuccess else {
                throw ClientAPIError.invalidConfiguration
            }
        } else if result != errSecSuccess {
            throw ClientAPIError.invalidConfiguration
        }
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func nonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 24)
        let status = bytes.withUnsafeMutableBytes { pointer in
            SecRandomCopyBytes(kSecRandomDefault, pointer.count, pointer.baseAddress!)
        }
        if status != errSecSuccess { return UUID().uuidString.replacingOccurrences(of: "-", with: "") }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
