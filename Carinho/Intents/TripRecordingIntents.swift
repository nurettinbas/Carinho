import AppIntents
import Foundation

struct StartTripRecordingIntent: AppIntent {
    nonisolated static var title: LocalizedStringResource { "shortcut.start.title" }
    nonisolated static var description: IntentDescription {
        IntentDescription("shortcut.start.description")
    }
    nonisolated static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        RecordingControlBridge.requestStartFromControlSurface()
        return .result()
    }
}

struct StopTripRecordingIntent: AppIntent {
    nonisolated static var title: LocalizedStringResource { "shortcut.stop.title" }
    nonisolated static var description: IntentDescription {
        IntentDescription("shortcut.stop.description")
    }
    nonisolated static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        RecordingControlBridge.requestStopFromControlSurface()
        return .result()
    }
}

struct PauseTripRecordingIntent: AppIntent {
    nonisolated static var title: LocalizedStringResource { "shortcut.pause.title" }
    nonisolated static var description: IntentDescription {
        IntentDescription("shortcut.pause.description")
    }
    nonisolated static var openAppWhenRun: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        RecordingControlBridge.requestPauseFromControlSurface()
        return .result()
    }
}

struct TodayKmQueryIntent: AppIntent {
    nonisolated static var title: LocalizedStringResource { "Bugünkü kilometre" }
    nonisolated static var description: IntentDescription {
        IntentDescription("Bugün kaydedilen toplam kilometresini söyler.")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let km = TodayKmProvider.todayKilometers()
        let spoken = String(format: "%.1f kilometre", km)
        return .result(value: spoken)
    }
}

struct CarinhoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTripRecordingIntent(),
            phrases: [
                "\(.applicationName) yolculuğu başlat",
                "Yolculuğu başlat \(.applicationName)",
                "\(.applicationName) ile yolculuğu başlat"
            ],
            shortTitle: "shortcut.start.title",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: StopTripRecordingIntent(),
            phrases: [
                "\(.applicationName) yolculuğu durdur",
                "Yolculuğu durdur \(.applicationName)"
            ],
            shortTitle: "shortcut.stop.title",
            systemImageName: "stop.circle"
        )
        AppShortcut(
            intent: PauseTripRecordingIntent(),
            phrases: [
                "\(.applicationName) yolculuğu duraklat",
                "Yolculuğu duraklat \(.applicationName)"
            ],
            shortTitle: "shortcut.pause.title",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: TodayKmQueryIntent(),
            phrases: [
                "Bugün kaç km sürdüm \(.applicationName)",
                "\(.applicationName) bugünkü km"
            ],
            shortTitle: "Bugünkü km",
            systemImageName: "road.lanes"
        )
    }
}

extension Notification.Name {
    static let carinhoStartRecording = Notification.Name("carinho.startRecording")
    static let carinhoStopRecording = Notification.Name("carinho.stopRecording")
}
