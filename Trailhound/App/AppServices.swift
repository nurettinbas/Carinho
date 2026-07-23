import SwiftData
import SwiftUI

/// Shared application services accessible from AppDelegate and SwiftUI.
@MainActor
enum AppServices {
    static let modelContainer: ModelContainer = {
        let container = ModelContainerFactory.makeSafe()
        UITestSupport.configureAppIfNeeded()
        UITestSupport.seedSampleTripIfNeeded(container: container)
        return container
    }()
    static let runtime = AppRuntime()

    static func bootstrapRecordingIfNeeded() {
        runtime.bootstrapRecording(container: modelContainer)
    }
}
