import CryptoKit
import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession

    private init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.connectionProxyDictionary = [:]
        configuration.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: configuration)
    }

    func cancelAllRequests() {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
    }

    func sendSigned<Body: SignedAPIRequest, Response: Decodable>(
        path: String,
        body: Body,
        bearerToken: String? = nil,
        responseType: Response.Type = Response.self
    ) async throws -> Response {
        guard await NetworkInterceptionGuard.shared.evaluate() else {
            throw ClientAPIError.networkInterceptionDetected
        }
        let bodyData = try JSONEncoder().encode(body)
        let request = try await signedRequest(
            path: path,
            method: "POST",
            body: bodyData,
            timestamp: body.timestamp,
            nonce: body.nonce,
            bearerToken: bearerToken
        )
        do {
            let (data, response) = try await session.data(for: request)
            return try decode(responseType, data: data, response: response)
        } catch let error as ClientAPIError {
            throw error
        } catch is URLError {
            throw ClientAPIError.networkUnavailable
        }
    }

    func downloadPatch(token: String) async throws -> Data {
        guard await NetworkInterceptionGuard.shared.evaluate() else {
            throw ClientAPIError.networkInterceptionDetected
        }
        var request = URLRequest(url: try endpoint("/api/v1/download/3105"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-3105-patch", forHTTPHeaderField: "Accept")
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ClientAPIError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                throw decodeServerError(data: data, status: http.statusCode)
            }
            return data
        } catch let error as ClientAPIError {
            throw error
        } catch is URLError {
            throw ClientAPIError.networkUnavailable
        }
    }

    private func signedRequest(
        path: String,
        method: String,
        body: Data,
        timestamp: Int,
        nonce: String,
        bearerToken: String?
    ) async throws -> URLRequest {
        let url = try endpoint(path)
        let digest = SHA256.hash(data: body)
        let bodyHash = digest.map { String(format: "%02x", $0) }.joined()
        let canonical = "\(method)\n\(path)\n\(timestamp)\n\(nonce)\n\(bodyHash)"
        let signature = try await DeviceIdentityProvider.shared.sign(Data(canonical.utf8))
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(signature, forHTTPHeaderField: "X-Device-Signature")
        if let bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func endpoint(_ path: String) throws -> URL {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "PatchCloudWebsiteURL") as? String,
              let base = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              base.scheme?.lowercased() == "https",
              base.host != nil,
              let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            throw ClientAPIError.invalidConfiguration
        }
        return url
    }

    private func decode<Response: Decodable>(
        _ type: Response.Type,
        data: Data,
        response: URLResponse
    ) throws -> Response {
        guard let http = response as? HTTPURLResponse else { throw ClientAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw decodeServerError(data: data, status: http.statusCode)
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw ClientAPIError.invalidResponse
        }
    }

    private func decodeServerError(data: Data, status: Int) -> ClientAPIError {
        let payload = try? JSONDecoder().decode(ClientAPIErrorResponse.self, from: data)
        let code = payload?.code ?? "http_\(status)"
        let message = payload?.message ?? "Máy chủ từ chối yêu cầu."
        switch code {
        case "session_expired": return .sessionExpired
        case "token_expired": return .tokenExpired
        case "token_already_used": return .tokenAlreadyUsed
        case "license_invalid", "license_banned", "license_expired", "device_limit_reached":
            return .licenseInvalid(message)
        default: return .server(code: code, message: message)
        }
    }
}
