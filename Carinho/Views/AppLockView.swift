import SwiftUI

struct AppLockView: View {
    @Environment(AppLockService.self) private var appLockService
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
            Text("Carinho kilitli")
                .font(.title2)
            Button("Kilidi aç") {
                Task { @MainActor in
                    _ = await appLockService.authenticateIfNeeded(enabled: settings.appLockEnabled)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
    }
}
