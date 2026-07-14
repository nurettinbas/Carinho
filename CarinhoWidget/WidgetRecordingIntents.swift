@preconcurrency import AppIntents
import Foundation

struct WidgetStopRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Kaydı durdur"
    static let openAppWhenRun = false
    static var isDiscoverable: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        await RecordingControlBridge.handleStopButtonPressed()
        return .result()
    }
}

struct WidgetPauseRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Kaydı duraklat"
    static let openAppWhenRun = false
    static var isDiscoverable: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        await RecordingControlBridge.handlePauseButtonPressed()
        return .result()
    }
}

struct WidgetResumeRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Kayda devam et"
    static let openAppWhenRun = false
    static var isDiscoverable: Bool { false }

    @MainActor
    func perform() async throws -> some IntentResult {
        await RecordingControlBridge.handleResumeButtonPressed()
        return .result()
    }
}
