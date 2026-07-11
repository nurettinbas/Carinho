import CoreMotion
import Foundation

@MainActor
@Observable
final class MotionActivityService {
    private(set) var isAutomotive = false
    private(set) var isAuthorized = false

    var onAutomotiveChanged: ((Bool) -> Void)?

    private let manager = CMMotionActivityManager()
    private var isMonitoring = false

    var isActivityAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }

    func startMonitoring() {
        guard isActivityAvailable, !isMonitoring else { return }
        isMonitoring = true

        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let clearlyNotDriving = activity.walking || activity.running || activity.cycling
                let automotive = activity.automotive && !clearlyNotDriving
                if automotive != self.isAutomotive {
                    self.isAutomotive = automotive
                    self.onAutomotiveChanged?(automotive)
                }
            }
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        manager.stopActivityUpdates()
        isAutomotive = false
    }

    func refreshAuthorizationStatus() {
        switch CMMotionActivityManager.authorizationStatus() {
        case .authorized:
            isAuthorized = true
        case .denied, .restricted, .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    func requestPermission() {
        Task {
            await resolvePermissionPrompt()
        }
    }

    /// Triggers the system prompt when needed and waits until the user responds.
    func resolvePermissionPrompt() async {
        refreshAuthorizationStatus()
        guard !isAuthorized else { return }
        guard isActivityAvailable else { return }

        startMonitoring()
        await waitForAuthorizationDecision()
    }

    private func waitForAuthorizationDecision() async {
        for _ in 0..<40 {
            try? await Task.sleep(for: .milliseconds(250))
            refreshAuthorizationStatus()
            if CMMotionActivityManager.authorizationStatus() != .notDetermined {
                return
            }
        }
    }
}
