@preconcurrency import AppIntents
import Foundation

struct WidgetStartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Kaydı başlat"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await RecordingControlBridge.handleStartButtonPressed()
        return .result()
    }
}

struct WidgetStopRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Kaydı durdur"
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await RecordingControlBridge.handleStopButtonPressed()
        return .result()
    }
}

struct WidgetPauseRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Kaydı duraklat"
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await RecordingControlBridge.handlePauseButtonPressed()
        return .result()
    }
}

struct WidgetResumeRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Kayda devam et"
    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult {
        await RecordingControlBridge.handleResumeButtonPressed()
        return .result()
    }
}
