import AVFoundation
import Combine
import SwiftData
import SwiftUI

struct PairingTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(BluetoothTriggerService.self) private var bluetoothService
    @Environment(LocationService.self) private var locationService
    @Bindable private var settings = AppSettings.shared
    @Query private var vehicles: [VehicleProfile]

    @State private var refreshToken = 0
    @State private var vehiclePendingDeleteID: UUID?
    @State private var showDeleteConfirmation = false
    @State private var navigationPath = NavigationPath()

    private var sortedVehicles: [VehicleProfile] {
        vehicles.sorted { lhs, rhs in
            let lhsPaired = VehiclePairingService.isActivelyPaired(vehicleID: lhs.id, settings: settings)
            let rhsPaired = VehiclePairingService.isActivelyPaired(vehicleID: rhs.id, settings: settings)
            if lhsPaired != rhsPaired { return lhsPaired }
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var liveConnectionDetected: Bool {
        PairingConnectionStatus.isAnyConnectionDetected(bluetoothService: bluetoothService)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            pairingList
                .navigationDestination(for: UUID.self) { vehicleID in
                    PairingVehicleEditorView(vehicleID: vehicleID)
                }
        }
    }

    private var pairingList: some View {
        List {
            if !settings.hasAutoTriggerVehicle {
                Section {
                    LocationAlwaysRequiredBanner()
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                }
            }

            Section {
                PairingLiveConnectionBanner(
                    bluetoothService: bluetoothService,
                    refreshToken: refreshToken
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if sortedVehicles.isEmpty {
                Section {
                    PairingEmptyState {
                        addFirstVehicle()
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
                }
            } else {
                Section(sortedVehicles.count == 1 ? L10n.pairingTabVehicleSection : L10n.pairingTabSavedVehicles) {
                    ForEach(sortedVehicles, id: \.id) { vehicle in
                        vehicleRow(vehicle)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    vehiclePendingDeleteID = vehicle.id
                                    showDeleteConfirmation = true
                                } label: {
                                    Label(L10n.delete, systemImage: "trash")
                                }
                            }
                    }

                    Button(action: addVehiclePrompt) {
                        Label(L10n.pairingTabAddVehicle, systemImage: "plus.circle.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                    }
                    .tint(TrailhoundBrandColors.brandBottom)
                }
            }

            if settings.developerModeEnabled {
                AutoRecordingEventLogSection()
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.pairingTabTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                LocationPermissionBadge(state: locationService.authorizationState)
            }
            .hideSharedToolbarBackgroundIfAvailable()
        }
        .onAppear {
            refreshConnectionState()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshConnectionState()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
                .receive(on: DispatchQueue.main)
        ) { _ in
            // Bluetooth connect/disconnect surfaces as an audio route change;
            // refresh the live banner instantly instead of waiting for a tab re-entry.
            refreshConnectionState()
        }
        .alert(L10n.pairingTabDeleteVehicleTitle, isPresented: $showDeleteConfirmation) {
            Button(L10n.delete, role: .destructive) {
                deletePendingVehicle()
            }
            Button(L10n.cancel, role: .cancel) {
                vehiclePendingDeleteID = nil
            }
        } message: {
            if let vehiclePendingDeleteID,
               VehiclePairingService.isActivelyPaired(vehicleID: vehiclePendingDeleteID, settings: settings) {
                Text(L10n.pairingTabDeleteVehicleMessageActive)
            } else {
                Text(L10n.pairingTabDeleteVehicleMessage)
            }
        }
    }

    private func vehicleRow(_ vehicle: VehicleProfile) -> some View {
        PairingVehicleRow(
            vehicle: vehicle,
            isAutoStartActive: isAutoStartActive(for: vehicle),
            subtitle: vehicleSubtitle(vehicle),
            showsAutoStartButton: showsAutoStartButton(for: vehicle),
            onOpen: { openEditor(for: vehicle.id) },
            onAutoStart: { confirmVehicleIdentity(vehicle) },
            onRemoveAutoStart: { removeAutoStart(for: vehicle) }
        )
    }

    private func isAutoStartActive(for vehicle: VehicleProfile) -> Bool {
        VehiclePairingService.isActivelyPaired(vehicleID: vehicle.id, settings: settings)
    }

    private func showsAutoStartButton(for vehicle: VehicleProfile) -> Bool {
        PairingConnectionStatus.shouldOfferVehicleConfirmation(
            for: vehicle,
            settings: settings,
            bluetoothService: bluetoothService
        )
    }

    private func vehicleSubtitle(_ vehicle: VehicleProfile) -> String {
        let consumption = String(format: "%.1f %@", vehicle.consumption, vehicle.consumptionLabel)
        var parts = [vehicle.fuelType.displayName, consumption]

        if isAutoStartActive(for: vehicle) {
            parts.append(PairingConnectionStatus.connectionSummary(for: vehicle))
        } else if liveConnectionDetected,
                  PairingConnectionStatus.isVehicleChannelConnected(
                    vehicle: vehicle,
                    settings: settings,
                    bluetoothService: bluetoothService
                  ) {
            parts.append(VehiclePairingService.detectLiveConnection(bluetoothService: bluetoothService).displayLabel())
        }

        return parts.joined(separator: " · ")
    }

    private func refreshConnectionState() {
        bluetoothService.refreshMonitoring()
        VehicleConnectionCoordinator.shared.reloadConfiguration()
        refreshToken &+= 1
    }

    private func suggestedVehicleName() -> String {
        let base = L10n.vehicleDefaultName
        let existing = Set(vehicles.map(\.name))
        if !existing.contains(base) { return base }
        var index = 2
        while existing.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func openEditor(for vehicleID: UUID) {
        Task { @MainActor in
            await Task.yield()
            navigationPath.append(vehicleID)
        }
    }

    private func addFirstVehicle() {
        let vehicle = VehicleProfile(
            name: suggestedVehicleName(),
            consumption: settings.fuelLitersPer100km
        )
        modelContext.insert(vehicle)
        guard (try? modelContext.save()) != nil else { return }
        VehiclePairingService.setDefaultVehicle(vehicle, in: modelContext)
        refreshConnectionState()
    }

    private func addVehiclePrompt() {
        let vehicle = VehicleProfile(
            name: suggestedVehicleName(),
            consumption: settings.fuelLitersPer100km
        )
        modelContext.insert(vehicle)
        guard (try? modelContext.save()) != nil else { return }
        openEditor(for: vehicle.id)
    }

    private func deletePendingVehicle() {
        guard let vehiclePendingDeleteID,
              let vehicle = vehicles.first(where: { $0.id == vehiclePendingDeleteID }) else {
            self.vehiclePendingDeleteID = nil
            return
        }

        if !navigationPath.isEmpty {
            navigationPath = NavigationPath()
        }

        VehiclePairingService.deleteVehicle(vehicle, in: modelContext)
        self.vehiclePendingDeleteID = nil
        refreshConnectionState()
    }

    private func confirmVehicleIdentity(_ vehicle: VehicleProfile) {
        refreshConnectionState()

        let live = VehiclePairingService.detectLiveConnection(bluetoothService: bluetoothService)
        guard live.isDetected else {
            AppErrorPresenter.shared.present(L10n.pairingTabWaitingConnection)
            return
        }

        VehiclePairingService.confirmLiveConnection(
            vehicle: vehicle,
            live: live,
            in: modelContext
        )
        settings.skipCarSetup()
        TrailhoundHaptics.pairingSucceeded()
        refreshConnectionState()
    }

    private func removeAutoStart(for vehicle: VehicleProfile) {
        guard isAutoStartActive(for: vehicle) else { return }
        VehiclePairingService.unpair(in: modelContext)
        refreshConnectionState()
    }
}

#Preview {
    PairingTabView()
        .modelContainer(PreviewData.shared.container)
        .environment(BluetoothTriggerService())
        .environment(LocationService())
        .environment(PreviewData.shared.recordingService)
}
