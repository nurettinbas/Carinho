import SwiftUI
import WatchConnectivity

private enum WatchFormatters {
    static func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func formatDistance(_ meters: Double) -> String {
        String(format: "%.1f km", meters / 1000)
    }
}

@main
struct CarinhoWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(connectivity)
        }
    }
}

final class WatchConnectivityModel: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var elapsed: TimeInterval = 0
    @Published var distanceMeters: Double = 0

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func send(action: String) {
        guard WCSession.default.activationState == .activated else { return }
        WCSession.default.sendMessage(["action": action], replyHandler: nil)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.isRecording = applicationContext["isRecording"] as? Bool ?? false
            self.isPaused = applicationContext["isPaused"] as? Bool ?? false
            self.elapsed = applicationContext["elapsed"] as? TimeInterval ?? 0
            self.distanceMeters = applicationContext["distance"] as? Double ?? 0
        }
    }
}

struct WatchContentView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityModel

    var body: some View {
        VStack(spacing: 12) {
            Label("Carinho", systemImage: "car.fill")
                .font(.headline)

            if connectivity.isRecording || connectivity.isPaused {
                Text(connectivity.isPaused ? "Duraklatıldı" : "Kayıt")
                    .font(.caption)
                    .foregroundStyle(connectivity.isPaused ? .orange : .red)
                Text(WatchFormatters.formatDuration(connectivity.elapsed))
                    .font(.title3.bold())
                    .monospacedDigit()
                Text(WatchFormatters.formatDistance(connectivity.distanceMeters))
                    .foregroundStyle(.secondary)
                Button("Durdur") { connectivity.send(action: "stop") }
                    .tint(.red)
            } else {
                Text("Kayıt yok")
                    .foregroundStyle(.secondary)
                Button("Başlat") { connectivity.send(action: "start") }
            }
        }
        .padding()
    }
}
