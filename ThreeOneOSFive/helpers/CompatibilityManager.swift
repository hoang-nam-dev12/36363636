import Foundation

@MainActor
final class CompatibilityManager: ObservableObject {
    static let shared = CompatibilityManager()

    @Published private(set) var environment = DeviceEnvironment.current
    @Published private(set) var state: CapabilityState = .unknown

    private let networkProvider = NetworkOnlyAccessProvider()

    private init() {}

    func probe() async {
        environment = .current
        state = .detected
        var capabilities = await networkProvider.probe(environment: environment)

        guard ExploitSupportPolicy.supportsCompiledSystemAccess(
            major: environment.osMajor,
            minor: environment.osMinor,
            patch: environment.osPatch,
            build: environment.build
        ) else {
            state = .verified(capabilities)
            return
        }

        state = .supportedCandidate
        if KernelExploit.hasSandboxAccess() {
            capabilities.insert(.containerRead)
            capabilities.insert(.containerWrite)
            capabilities.insert(.appGroupAccess)
            capabilities.insert(.kernelReadWrite)
            capabilities.insert(.sandboxEscape)
            capabilities.insert(.patchInstall)
            capabilities.insert(.patchRestore)
        }
        state = .verified(capabilities)
    }
}
