import CryptoKit
import Foundation

actor PatchDownloadManager {
    static let shared = PatchDownloadManager()

    struct Payload: Sendable {
        let data: Data
        let password: String?
    }

    func download(fileIDs: [String], licenseKey: String) async throws -> [String: Payload] {
        let unique = Array(Set(fileIDs))
        guard !unique.isEmpty, unique.count <= 10 else { throw ClientAPIError.downloadFailed }
        let session = try await AuthenticationService.shared.authenticate(licenseKey: licenseKey)
        let identity = DeviceIdentityProvider.shared
        let request = DownloadTokenRequest(
            fileIds: unique,
            deviceId: try await identity.deviceID(),
            timestamp: Int(Date().timeIntervalSince1970),
            nonce: AuthenticationService.nonce()
        )
        let tokenResponse: DownloadTokenResponse = try await APIClient.shared.sendSigned(
            path: "/api/v1/download/token",
            body: request,
            bearerToken: session.token
        )
        guard tokenResponse.success, tokenResponse.downloads.count == unique.count else {
            throw ClientAPIError.invalidResponse
        }

        let metadata = Dictionary(uniqueKeysWithValues: session.response.files.map { ($0.fileId, $0) })
        return try await withThrowingTaskGroup(of: (String, Payload).self) { group in
            for download in tokenResponse.downloads {
                group.addTask {
                    let data = try await APIClient.shared.downloadPatch(token: download.token)
                    guard data.count == download.size else { throw ClientAPIError.integrityFailed }
                    let checksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                    guard checksum.caseInsensitiveCompare(download.sha256) == .orderedSame else {
                        throw ClientAPIError.integrityFailed
                    }
                    return (download.fileId, Payload(data: data, password: metadata[download.fileId]?.password))
                }
            }
            var result: [String: Payload] = [:]
            for try await (fileID, payload) in group { result[fileID] = payload }
            return result
        }
    }
}
