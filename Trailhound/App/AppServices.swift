import SwiftData
import SwiftUI

/// Shared application services accessible from AppDelegate, CarPlay, and SwiftUI.
@MainActor
enum AppServices {
    static let modelContainer: ModelContainer = ModelContainerFactory.makeSafe()
    static let runtime = AppRuntime()

    static func bootstrapRecordingIfNeeded() {
        runtime.bootstrapRecording(container: modelContainer)
    }
}
