import Foundation

enum ExploitSupportPolicy {
    static let verifiedIOS17Range = "17.0–17.7.x"
    static let verifiedIOS18Range = "18.0–18.7.1"
    static let verifiedIOS26Range = "26.0.x"

    static func supportsKernelExploit(major: Int, minor: Int, patch: Int) -> Bool {
        guard minor >= 0, patch >= 0 else { return false }

        if major == 17 {
            return minor <= 7
        }

        if major == 18 {
            return minor < 7 || (minor == 7 && patch <= 1)
        }

        return false
    }

    /// The SwiftUI, network and .3105 codec layers compile and run on iOS 16+.
    /// This does not imply that privileged container/system access is available.
    static func supportsAppRuntime(major: Int) -> Bool {
        major >= 16
    }

    /// Mirrors the backend that is actually compiled into this target. The
    /// native offsets table accepts verified iOS 17/18 builds and iOS 26.0,
    /// but has no iOS 16 or iOS 27 offsets. Unknown builds fail closed.
    static func supportsCompiledSystemAccess(
        major: Int,
        minor: Int,
        patch: Int,
        build: String
    ) -> Bool {
        guard !build.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if supportsKernelExploit(major: major, minor: minor, patch: patch) {
            return true
        }
        return major == 26 && minor == 0 && patch >= 0
    }

    static func isSupported(major: Int, minor: Int, patch: Int, build: String) -> Bool {
        supportsCompiledSystemAccess(
            major: major,
            minor: minor,
            patch: patch,
            build: build
        )
    }
}
