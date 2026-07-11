import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppLockService.self) private var appLockService
    @Environment(TripRecordingService.self) private var tripRecordingService
    @Environment(BluetoothTriggerService.self) private var bluetoothService
    @Environment(\.modelContext) private var modelContext
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
        .onChange(of: tabSelection.selectedTab) { _, tab in
            guard tab == .pairing else { return }
            evaluateVehicleIdentityPrompt()
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
        .alert(L10n.vehicleIdentityPromptTitle, isPresented: vehicleIdentityConfirmationBinding) {
            Button(L10n.pairingAutoStart) {
                confirmVehicleIdentityFromPrompt()
            }
            Button(L10n.cancel, role: .cancel) {
                dismissVehicleIdentityPrompt()
            }
        } message: {
            Text(vehicleIdentityPromptMessage)
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

    private var vehicleIdentityConfirmationBinding: Binding<Bool> {
        Binding(
            get: { settings.awaitingVehicleIdentityConfirmation },
            set: { newValue in
                if !newValue, settings.awaitingVehicleIdentityConfirmation {
                    dismissVehicleIdentityPrompt()
                }
            }
        )
    }

    private var vehicleIdentityPromptMessage: String {
        let vehicleName = vehicleIdentityPromptVehicle?.name ?? L10n.vehicleDefaultName
        let connection = settings.vehicleIdentityConfirmationConnectionLabel ?? ""
        return L10n.vehicleIdentityPromptMessage(vehicleName: vehicleName, connection: connection)
    }

    private var vehicleIdentityPromptVehicle: VehicleProfile? {
        guard let vehicleID = settings.vehicleIdentityConfirmationVehicleID else { return nil }
        let vehicles = (try? modelContext.fetch(FetchDescriptor<VehicleProfile>())) ?? []
        return vehicles.first { $0.id == vehicleID }
    }

    private func confirmVehicleIdentityFromPrompt() {
        guard let vehicle = vehicleIdentityPromptVehicle else {
            settings.clearVehicleIdentityPrompt()
            return
        }
        let live = VehiclePairingService.detectLiveConnection(bluetoothService: bluetoothService)
        VehiclePairingService.confirmLiveConnection(
            vehicle: vehicle,
            live: live,
            in: modelContext
        )
        settings.skipCarSetup()
        CarinhoHaptics.pairingSucceeded()
    }

    private func dismissVehicleIdentityPrompt() {
        let live = VehiclePairingService.detectLiveConnection(bluetoothService: bluetoothService)
        VehiclePairingService.dismissVehicleIdentityPrompt(live: live.isDetected ? live : nil)
    }

    private func evaluateVehicleIdentityPrompt() {
        VehiclePairingService.evaluateVehicleIdentityPrompt(
            in: modelContext,
            bluetoothService: bluetoothService
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.shared.container)
        .environment(PreviewData.shared.recordingService)
        .environment(LocationService())
        .environment(MotionActivityService())
        .environment(AppLockService())
        .environment(BluetoothTriggerService())
        .environment(GeocodingRetryService(geocodingService: GeocodingService()))
        .environment(NetworkMonitor.shared)
}
