@preconcurrency import AppIntents
import Foundation

struct WidgetStopRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "shortcut.stop.title"
    static let openAppWhenRun = false
    static var isDiscoverable: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        DevLog.shared.log(.widget, "WidgetStopRecordingIntent performed")
        await RecordingControlBridge.handleStopButtonPressed()
        return .result()
    }
}

struct WidgetPauseRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "shortcut.pause.title"
    static let openAppWhenRun = false
    static var isDiscoverable: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        DevLog.shared.log(.widget, "WidgetPauseRecordingIntent performed")
        await RecordingControlBridge.handlePauseButtonPressed()
        return .result()
    }
}

struct WidgetResumeRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "shortcut.resume.title"
    static let openAppWhenRun = false
    static var isDiscoverable: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        DevLog.shared.log(.widget, "WidgetResumeRecordingIntent performed")
        await RecordingControlBridge.handleResumeButtonPressed()
        return .result()
    }
}
