import AppIntents
import Foundation

@MainActor
private func performRecordingShortcut(_ request: () -> Void) {
    AppServices.bootstrapRecordingIfNeeded()
    request()
    AppServices.runtime.processPendingRecordingRequests()
}

struct StartTripRecordingIntent: AppIntent {
    nonisolated static var title: LocalizedStringResource { "shortcut.start.title" }
    nonisolated static var description: IntentDescription {
        IntentDescription("shortcut.start.description")
    }
    nonisolated static var openAppWhenRun: Bool { true }
    nonisolated static var isDiscoverable: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        performRecordingShortcut {
            RecordingControlBridge.requestStartFromControlSurface()
        }
        return .result(dialog: IntentDialog("shortcut.start.success"))
    }
}

struct StopTripRecordingIntent: AppIntent {
    nonisolated static var title: LocalizedStringResource { "shortcut.stop.title" }
    nonisolated static var description: IntentDescription {
        IntentDescription("shortcut.stop.description")
    }
    nonisolated static var openAppWhenRun: Bool { false }
    nonisolated static var isDiscoverable: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        performRecordingShortcut {
            RecordingControlBridge.requestStopFromControlSurface()
        }
        return .result(dialog: IntentDialog("shortcut.stop.success"))
    }
}

struct PauseTripRecordingIntent: AppIntent {
    nonisolated static var title: LocalizedStringResource { "shortcut.pause.title" }
    nonisolated static var description: IntentDescription {
        IntentDescription("shortcut.pause.description")
    }
    nonisolated static var openAppWhenRun: Bool { false }
    nonisolated static var isDiscoverable: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        performRecordingShortcut {
            RecordingControlBridge.requestPauseFromControlSurface()
        }
        return .result(dialog: IntentDialog("shortcut.pause.success"))
    }
}

struct ResumeTripRecordingIntent: AppIntent {
    nonisolated static var title: LocalizedStringResource { "shortcut.resume.title" }
    nonisolated static var description: IntentDescription {
        IntentDescription("shortcut.resume.description")
    }
    nonisolated static var openAppWhenRun: Bool { false }
    nonisolated static var isDiscoverable: Bool { true }

    @MainActor
    func perform() async throws -> some IntentResult {
        performRecordingShortcut {
            RecordingControlBridge.requestResumeFromControlSurface()
        }
        return .result(dialog: IntentDialog("shortcut.resume.success"))
    }
}

struct TodayKmQueryIntent: AppIntent {
    nonisolated static var title: LocalizedStringResource { "shortcut.today.title" }
    nonisolated static var description: IntentDescription {
        IntentDescription(
            "shortcut.today.description",
            resultValueName: "shortcut.today.result"
        )
    }
    nonisolated static var openAppWhenRun: Bool { false }
    nonisolated static var isDiscoverable: Bool { false }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let km = TodayKmProvider.todayKilometers()
        let spoken = String(format: "%.1f km", km)
        return .result(value: spoken)
    }
}

struct CarinhoShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .blue }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTripRecordingIntent(),
            phrases: [
                "Yolculuğu başlat \(.applicationName)",
                "\(.applicationName) yolculuğu başlat",
                "\(.applicationName) ile yolculuğu başlat",
                "Start trip in \(.applicationName)",
                "Start trip with \(.applicationName)"
            ],
            shortTitle: "shortcut.start.title",
            systemImageName: "play.circle"
        )
        AppShortcut(
            intent: PauseTripRecordingIntent(),
            phrases: [
                "Yolculuğu duraklat \(.applicationName)",
                "\(.applicationName) yolculuğu duraklat",
                "Pause trip in \(.applicationName)",
                "Pause trip with \(.applicationName)"
            ],
            shortTitle: "shortcut.pause.title",
            systemImageName: "pause.circle"
        )
        AppShortcut(
            intent: ResumeTripRecordingIntent(),
            phrases: [
                "Yolculuğu sürdür \(.applicationName)",
                "\(.applicationName) yolculuğu sürdür",
                "Resume trip in \(.applicationName)",
                "Resume trip with \(.applicationName)"
            ],
            shortTitle: "shortcut.resume.title",
            systemImageName: "playpause.circle"
        )
        AppShortcut(
            intent: StopTripRecordingIntent(),
            phrases: [
                "Yolculuğu bitir \(.applicationName)",
                "\(.applicationName) yolculuğu bitir",
                "\(.applicationName) ile yolculuğu bitir",
                "End trip in \(.applicationName)",
                "End trip with \(.applicationName)"
            ],
            shortTitle: "shortcut.stop.title",
            systemImageName: "stop.circle"
        )
    }
}
