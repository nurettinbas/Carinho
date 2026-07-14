import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppLockService.self) private var appLockService
    @Environment(TripRecordingService.self) private var tripRecordingService
    @Bindable private var settings = AppSettings.shared
    @Bindable private var tabSelection = TabSelection.shared

    var body: some View {
        if !settings.hasCompletedOnboarding {
            OnboardingView()
        } else if settings.appLockEnabled && !appLockService.isUnlocked {
            AppLockView()
        } else {
            mainTabs
        }
    }

    private var mainTabs: some View {
        TabView(selection: $tabSelection.selectedTab) {
            NavigationStack { TripListView() }
                .tabItem { Label(L10n.tabTrips, systemImage: "list.bullet") }
                .badge(tripRecordingService.state.isActiveSession ? "" : nil)
                .tag(AppTab.trips)

            NavigationStack { StatsView() }
                .tabItem { Label(L10n.tabStats, systemImage: "chart.bar") }
                .tag(AppTab.stats)

            PairingTabView()
                .tabItem { Label(L10n.tabPairing, systemImage: "link.circle") }
                .tag(AppTab.pairing)

            NavigationStack { SettingsView() }
                .tabItem { Label(L10n.tabSettings, systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .task {
            await authenticateOnLaunch()
            processPendingRecordingRequests()
        }
        .onChange(of: appLockService.isUnlocked) { _, isUnlocked in
            if isUnlocked {
                processPendingRecordingRequests()
            }
        }
        .alert(L10n.externalStartConfirmTitle, isPresented: externalStartConfirmationBinding) {
            Button(L10n.externalStartConfirmAction) {
                tripRecordingService.confirmExternalStartRecording()
            }
            Button(L10n.cancel, role: .cancel) {
                tripRecordingService.cancelExternalStartRecording()
            }
        } message: {
            Text(L10n.externalStartConfirmMessage)
        }
        .appErrorAlert()
    }

    @MainActor
    private func authenticateOnLaunch() async {
        _ = await appLockService.authenticateIfNeeded(enabled: settings.appLockEnabled)
    }

    private func processPendingRecordingRequests() {
        settings.expireStaleRecordingRequests()
        if settings.pendingStopRecordingRequest {
            tripRecordingService.processExternalStopRequest()
            return
        }
        if settings.pendingStartRecordingRequest || settings.awaitingExternalStartConfirmation {
            tripRecordingService.processExternalStartRequest()
            return
        }
        if settings.pendingPauseRecordingRequest {
            tripRecordingService.processExternalPauseRequest()
            return
        }
        if settings.pendingResumeRecordingRequest {
            tripRecordingService.processExternalResumeRequest()
        }
    }

    private var externalStartConfirmationBinding: Binding<Bool> {
        Binding(
            get: { settings.awaitingExternalStartConfirmation },
            set: { newValue in
                if !newValue, settings.awaitingExternalStartConfirmation {
                    tripRecordingService.cancelExternalStartRecording()
                }
            }
        )
    }

}

#Preview {
    ContentView()
        .modelContainer(PreviewData.shared.container)
        .environment(PreviewData.shared.recordingService)
        .environment(LocationService())
        .environment(AppLockService())
        .environment(BluetoothTriggerService())
        .environment(GeocodingRetryService(geocodingService: GeocodingService()))
        .environment(NetworkMonitor.shared)
}
