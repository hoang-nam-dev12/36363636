import CryptoKit
import Foundation
import Security

actor DeviceIdentityProvider {
    static let shared = DeviceIdentityProvider()

    private let service = "com.apple.mobile.MobileHouseArrest.device-identity.v1"
    private let account = "signing-key"
    private var cachedKey: SigningKey?

    private enum SigningKey {
        case secureEnclave(SecureEnclave.P256.Signing.PrivateKey)
        case software(P256.Signing.PrivateKey)

        var publicKey: P256.Signing.PublicKey {
            switch self {
            case let .secureEnclave(key): return key.publicKey
            case let .software(key): return key.publicKey
            }
        }

        func signature(for data: Data) throws -> P256.Signing.ECDSASignature {
            switch self {
            case let .secureEnclave(key): return try key.signature(for: data)
            case let .software(key): return try key.signature(for: data)
            }
        }

        var storedRepresentation: Data {
            var representation: Data
            switch self {
            case let .secureEnclave(key):
                representation = Data([1])
                representation.append(key.dataRepresentation)
            case let .software(key):
                representation = Data([2])
                representation.append(key.rawRepresentation)
            }
            return representation
        }
    }

    func publicKey() throws -> String {
        try Self.base64URL(loadOrCreateKey().publicKey.x963Representation)
    }

    func deviceID() throws -> String {
        let digest = SHA256.hash(data: loadOrCreateKey().publicKey.x963Representation)
        return "dms-" + Data(digest).map { String(format: "%02x", $0) }.joined()
    }

    func sign(_ data: Data) throws -> String {
        try Self.base64URL(loadOrCreateKey().signature(for: data).rawRepresentation)
    }

    private func loadOrCreateKey() throws -> SigningKey {
        if let cachedKey { return cachedKey }
        if let stored = readKeychain(), stored.count > 1 {
            let payload = Data(stored.dropFirst())
            if stored[0] == 1,
               SecureEnclave.isAvailable,
               let key = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: payload) {
                let value = SigningKey.secureEnclave(key)
                cachedKey = value
                return value
            }
            if stored[0] == 2,
               let key = try? P256.Signing.PrivateKey(rawRepresentation: payload) {
                let value = SigningKey.software(key)
                cachedKey = value
                return value
            }
        }

        let key: SigningKey
        if SecureEnclave.isAvailable,
           let secureKey = try? SecureEnclave.P256.Signing.PrivateKey() {
            key = .secureEnclave(secureKey)
        } else {
            key = .software(P256.Signing.PrivateKey())
        }
        try writeKeychain(key.storedRepresentation)
        cachedKey = key
        return key
    }

    private func readKeychain() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private func writeKeychain(_ data: Data) throws {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updated = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if updated == errSecItemNotFound {
            var insert = base
            attributes.forEach { insert[$0.key] = $0.value }
            let status = SecItemAdd(insert as CFDictionary, nil)
            guard status == errSecSuccess else { throw ClientAPIError.invalidConfiguration }
        } else if updated != errSecSuccess {
            throw ClientAPIError.invalidConfiguration
        }
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
