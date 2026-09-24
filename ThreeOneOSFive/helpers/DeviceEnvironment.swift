import Foundation

enum DeviceArchitecture: String, Codable {
    case arm64
    case arm64e
    case simulator
    case unknown
}

struct DeviceEnvironment: Codable, Equatable {
    let osMajor: Int
    let osMinor: Int
    let osPatch: Int
    let build: String
    let modelIdentifier: String
    let architecture: DeviceArchitecture
    let appVersion: String
    let appBuild: String

    static var current: DeviceEnvironment {
        let version = ProcessInfo.processInfo.operatingSystemVersion
#if targetEnvironment(simulator)
        let architecture: DeviceArchitecture = .simulator
#elseif arch(arm64)
        let architecture: DeviceArchitecture = .arm64
#else
        let architecture: DeviceArchitecture = .unknown
#endif
        return DeviceEnvironment(
            osMajor: version.majorVersion,
            osMinor: version.minorVersion,
            osPatch: version.patchVersion,
            build: AppInfo.osBuild,
            modelIdentifier: AppInfo.machineName,
            architecture: architecture,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        )
    }

    var versionString: String { "\(osMajor).\(osMinor).\(osPatch)" }
}

enum DeviceCapability: String, CaseIterable, Hashable {
    case containerRead
    case containerWrite
    case appGroupAccess
    case kernelReadWrite
    case sandboxEscape
    case patchInstall
    case patchRestore
    case repositoryDownload
}

struct DeviceCapabilities: Equatable {
    private(set) var values = Set<DeviceCapability>()

    init(_ values: Set<DeviceCapability> = []) {
        self.values = values
    }

    func contains(_ capability: DeviceCapability) -> Bool { values.contains(capability) }
    mutating func insert(_ capability: DeviceCapability) { values.insert(capability) }
}

enum CapabilityState: Equatable {
    case unknown
    case detected
    case supportedCandidate
    case initializing
    case verified(DeviceCapabilities)
    case unsupported(String)
    case initializationFailed(String)
    case verificationFailed(String)
}

protocol DeviceAccessProvider {
    var identifier: String { get }
    func probe(environment: DeviceEnvironment) async -> DeviceCapabilities
    func initialize(environment: DeviceEnvironment) async throws
}

struct NetworkOnlyAccessProvider: DeviceAccessProvider {
    let identifier = "network-only"

    func probe(environment: DeviceEnvironment) async -> DeviceCapabilities {
        DeviceCapabilities([.repositoryDownload])
    }

    func initialize(environment: DeviceEnvironment) async throws {
        // Network/package parsing needs no privileged system initialization.
    }
}
