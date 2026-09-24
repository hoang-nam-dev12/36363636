import CFNetwork
import Foundation
import SwiftUI

enum NetworkInterceptionDetection: Equatable, Sendable {
    case proxy

    var title: String { "PHÁT HIỆN CHẶN API" }

    var message: String {
        "Thiết bị đang bật HTTP/HTTPS/SOCKS Proxy hoặc cấu hình PAC. Hãy tắt ứng dụng bắt request rồi mở lại ứng dụng."
    }
}

enum NetworkInterceptionDetector {
    static func detect() -> NetworkInterceptionDetection? {
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-network-interception") {
            return .proxy
        }
        return nil
#endif
        if hasConfiguredProxy() { return .proxy }
        return nil
    }

    private static func hasConfiguredProxy() -> Bool {
        guard let unmanaged = CFNetworkCopySystemProxySettings() else { return false }
        let settingsDictionary = unmanaged.takeRetainedValue()
        let settings = settingsDictionary as NSDictionary
        let enableKeys: [CFString] = [
            kCFNetworkProxiesHTTPEnable,
            kCFNetworkProxiesProxyAutoConfigEnable
        ]
        if enableKeys.contains(where: { (settings[$0 as String] as? NSNumber)?.boolValue == true }) {
            return true
        }

        guard let rawBase = Bundle.main.object(forInfoDictionaryKey: "PatchCloudWebsiteURL") as? String,
              let baseURL = URL(string: rawBase) else {
            return false
        }
        let proxies = CFNetworkCopyProxiesForURL(baseURL as CFURL, settingsDictionary).takeRetainedValue() as NSArray
        let directType = kCFProxyTypeNone as String
        for case let proxy as NSDictionary in proxies {
            if let type = proxy[kCFProxyTypeKey as String] as? String, type != directType {
                return true
            }
        }
        return false
    }
}

@MainActor
final class NetworkInterceptionGuard: ObservableObject {
    static let shared = NetworkInterceptionGuard()

    @Published private(set) var detection: NetworkInterceptionDetection?
    @Published private(set) var secondsRemaining = 5

    private var countdownTask: Task<Void, Never>?

    private init() {
        detection = NetworkInterceptionDetector.detect()
    }

    var isBlocked: Bool { detection != nil }

    @discardableResult
    func evaluate() -> Bool {
        if detection == nil {
            detection = NetworkInterceptionDetector.detect()
        }
        guard detection == nil else {
            beginCountdownIfNeeded()
            return false
        }
        return true
    }

    func beginCountdownIfNeeded() {
        guard detection != nil, countdownTask == nil else { return }
        secondsRemaining = 5
        URLSession.shared.getAllTasks { tasks in tasks.forEach { $0.cancel() } }
        OnlineFileFetcher.shared.cancelNetworkRequests()
        Task { await APIClient.shared.cancelAllRequests() }
        FluxCoreAudioPlayer.shared.stop()
        FloatingWindowManager.shared.hide()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while self.secondsRemaining > 0 {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                } catch {
                    return
                }
                self.secondsRemaining -= 1
            }
            exit(EXIT_SUCCESS)
        }
    }
}

struct NetworkInterceptionBlockView: View {
    @ObservedObject var guardState: NetworkInterceptionGuard

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.05, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "network.slash")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(Color.red)
                    .padding(24)
                    .background(Color.red.opacity(0.12), in: Circle())
                    .overlay(Circle().stroke(Color.red.opacity(0.45), lineWidth: 1))

                Text(guardState.detection?.title ?? "PHÁT HIỆN CHẶN API")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                Text(guardState.detection?.message ?? "Hãy tắt ứng dụng bắt request rồi mở lại ứng dụng.")
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineSpacing(4)

                VStack(spacing: 8) {
                    Text("\(guardState.secondsRemaining)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.red)
                    Text("Ứng dụng sẽ tự đóng")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .padding(.top, 4)
            }
            .padding(28)
            .frame(maxWidth: 430)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.red.opacity(0.35), lineWidth: 1)
            )
            .padding(24)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Phát hiện Proxy. Ứng dụng sẽ đóng sau \(guardState.secondsRemaining) giây.")
    }
}
