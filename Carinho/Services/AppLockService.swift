import LocalAuthentication
import SwiftUI

@MainActor
@Observable
final class AppLockService {
    private(set) var isUnlocked = true

    func authenticateIfNeeded(enabled: Bool) async -> Bool {
        guard enabled else {
            isUnlocked = true
            return true
        }

        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            || context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isUnlocked = true
            return true
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Yolculuk geçmişinizi görmek için doğrulayın."
            )
            isUnlocked = success
            return success
        } catch {
            isUnlocked = false
            return false
        }
    }

    func lock() {
        isUnlocked = false
    }
}
