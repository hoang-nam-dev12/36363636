import Foundation

enum ClientAPIError: Error, LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case networkInterceptionDetected
    case server(code: String, message: String)
    case networkUnavailable
    case licenseInvalid(String)
    case sessionExpired
    case tokenExpired
    case tokenAlreadyUsed
    case downloadFailed
    case integrityFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "Ứng dụng chưa cấu hình API bảo mật."
        case .invalidResponse: return "Máy chủ trả về dữ liệu không hợp lệ."
        case .networkInterceptionDetected: return "Đã phát hiện Proxy/VPN có thể chặn request API."
        case let .server(_, message), let .licenseInvalid(message): return message
        case .networkUnavailable: return "Không thể kết nối máy chủ."
        case .sessionExpired: return "Phiên xác thực đã hết hạn."
        case .tokenExpired: return "Token tải file đã hết hạn."
        case .tokenAlreadyUsed: return "Token tải file đã được sử dụng."
        case .downloadFailed: return "Không thể tải patch."
        case .integrityFailed: return "Patch không vượt qua kiểm tra toàn vẹn."
        }
    }
}

protocol SignedAPIRequest: Encodable {
    var timestamp: Int { get }
    var nonce: String { get }
}

struct ClientAuthenticationRequest: SignedAPIRequest, Sendable {
    let licenseKey: String
    let deviceId: String
    let devicePublicKey: String
    let iosVersion: String
    let iosBuild: String
    let deviceModel: String
    let architecture: String
    let appVersion: String
    let appBuild: String
    let timestamp: Int
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case licenseKey = "license_key"
        case deviceId = "device_id"
        case devicePublicKey = "device_public_key"
        case iosVersion = "ios_version"
        case iosBuild = "ios_build"
        case deviceModel = "device_model"
        case architecture
        case appVersion = "app_version"
        case appBuild = "app_build"
        case timestamp, nonce
    }
}

struct ClientPatchDescriptor: Codable, Equatable, Sendable {
    let fileId: String
    let title: String
    let filename: String
    let sha256: String
    let size: Int
    let packageId: String?
    let game: String
    let category: String
    let password: String?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case title, filename, sha256, size
        case packageId = "package_id"
        case game, category, password
    }
}

struct ClientLicenseSummary: Codable, Equatable, Sendable {
    let expiresAt: Int?
    let lifetime: Bool
    let appName: String
    let note: String?

    enum CodingKeys: String, CodingKey {
        case expiresAt = "expires_at"
        case lifetime, note
        case appName = "app_name"
    }
}

struct ClientAuthenticationResponse: Codable, Equatable, Sendable {
    struct Device: Codable, Equatable, Sendable { let authorized: Bool; let id: String }
    struct Compatibility: Codable, Equatable, Sendable {
        let ios: String
        let build: String
        let status: String
        let localProbeRequired: Bool

        enum CodingKeys: String, CodingKey {
            case ios, build, status
            case localProbeRequired = "local_probe_required"
        }
    }
    struct Features: Codable, Equatable, Sendable {
        let repository: Bool
        let patches: Bool
        let ios16Experimental: Bool

        enum CodingKeys: String, CodingKey {
            case repository, patches
            case ios16Experimental = "ios16_experimental"
        }
    }

    let success: Bool
    let session: String
    let sessionExpiresAt: Int
    let device: Device
    let license: ClientLicenseSummary
    let compatibility: Compatibility
    let features: Features
    let files: [ClientPatchDescriptor]

    enum CodingKeys: String, CodingKey {
        case success, session, device, license, compatibility, features, files
        case sessionExpiresAt = "session_expires_at"
    }
}

struct DownloadTokenRequest: SignedAPIRequest, Sendable {
    let fileIds: [String]
    let deviceId: String
    let timestamp: Int
    let nonce: String

    enum CodingKeys: String, CodingKey {
        case fileIds = "file_ids"
        case deviceId = "device_id"
        case timestamp, nonce
    }
}

struct DownloadTokenResponse: Decodable, Sendable {
    struct Download: Decodable, Sendable {
        let fileId: String
        let token: String
        let expiresIn: Int
        let sha256: String
        let size: Int

        enum CodingKeys: String, CodingKey {
            case fileId = "file_id"
            case token, sha256, size
            case expiresIn = "expires_in"
        }
    }
    let success: Bool
    let downloads: [Download]
}

struct ClientAPIErrorResponse: Decodable, Sendable {
    let success: Bool?
    let code: String?
    let message: String?
}
