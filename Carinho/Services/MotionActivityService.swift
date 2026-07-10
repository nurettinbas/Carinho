import CoreMotion
import Foundation

@Observable
final class MotionActivityService {
    private(set) var isAutomotive = false
    private(set) var isAuthorized = false

    var onAutomotiveChanged: ((Bool) -> Void)?

    private let manager = CMMotionActivityManager()
    private var isMonitoring = false

    func startMonitoring() {
        guard CMMotionActivityManager.isActivityAvailable(), !isMonitoring else { return }
        isMonitoring = true

        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            let clearlyNotDriving = activity.walking || activity.running || activity.cycling
            let automotive = activity.automotive && !clearlyNotDriving
            if automotive != self.isAutomotive {
                self.isAutomotive = automotive
                self.onAutomotiveChanged?(automotive)
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
        case .denied, .restricted:
            isAuthorized = false
        case .notDetermined:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    func requestPermission() {
        startMonitoring()
    }
}
