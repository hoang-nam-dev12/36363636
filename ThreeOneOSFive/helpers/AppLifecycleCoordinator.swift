import Foundation

@MainActor
final class AppLifecycleCoordinator: ObservableObject {
    enum State: Equatable {
        case starting
        case checkingDevice
        case authenticating
        case authenticated
        case unsupported(reason: String)
        case ready
        case error(String)
    }

    @Published private(set) var state: State = .starting
    private var activeTask: Task<Void, Never>?
    private var lastActivation = Date.distantPast

    func becameActive() {
        guard NetworkInterceptionGuard.shared.evaluate() else { return }
        guard activeTask == nil else { return }
        guard Date().timeIntervalSince(lastActivation) > 1 else { return }
        lastActivation = Date()
        activeTask = Task { [weak self] in
            guard let self else { return }
            self.state = .checkingDevice
            await CompatibilityManager.shared.probe()
            let key = UserDefaults.standard.string(forKey: "saved_key")?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !key.isEmpty else {
                self.state = .ready
                self.activeTask = nil
                return
            }
            self.state = .authenticating
            do {
                _ = try await AuthenticationService.shared.authenticate(licenseKey: key)
                self.state = .authenticated
            } catch {
                self.state = .error(error.localizedDescription)
            }
            self.activeTask = nil
        }
    }

    func enteredBackground() {
        // Keep a still-valid session. Cancellation prevents a foreground request
        // from racing a transition that is no longer visible.
        activeTask?.cancel()
        activeTask = nil
    }
}
