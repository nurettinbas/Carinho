import SwiftData
import SwiftUI

struct CarPairingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(BluetoothTriggerService.self) private var bluetoothService
    @Bindable private var settings = AppSettings.shared
    @Query private var vehicles: [VehicleProfile]

    @State private var selectedType: PairedVehicleType = .bluetoothAudio
    @State private var carPlayRefreshToken = 0

    private var sortedVehicles: [VehicleProfile] {
        vehicles.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "car.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.blue)

                Text(L10n.vehiclePairingTitle)
                    .font(.title2.bold())

                Text(L10n.vehiclePairingMessage)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if !sortedVehicles.isEmpty {
                    savedVehiclesSection
                }

                Picker(L10n.vehiclePairingConnectionType, selection: $selectedType) {
                    Text(L10n.vehiclePairingBluetooth).tag(PairedVehicleType.bluetoothAudio)
                    Text(L10n.vehiclePairingCarPlay).tag(PairedVehicleType.carPlay)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Group {
                    switch selectedType {
                    case .bluetoothAudio:
                        bluetoothSection
                    case .carPlay:
                        carPlaySection
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button(L10n.vehiclePairingSkip) {
                    settings.hasCompletedCarSetup = true
                    dismiss()
                }
                .foregroundStyle(.secondary)
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                bluetoothService.syncRouteSnapshot()
                if settings.pairedVehicleType == .carPlay {
                    selectedType = .carPlay
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled()
    }

    @ViewBuilder
    private var savedVehiclesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.vehiclePairingSavedVehicles)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(sortedVehicles, id: \.id) { vehicle in
                Button {
                    pairSavedVehicle(vehicle)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(vehicle.name)
                                .foregroundStyle(.primary)
                            Text(savedVehicleSubtitle(vehicle))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if settings.activeAutoTriggerVehicleID == vehicle.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    @ViewBuilder
    private var bluetoothSection: some View {
        if let candidate = bluetoothService.connectedCarCandidate() {
            VStack(spacing: 8) {
                Text(L10n.vehiclePairingConnectedDevice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(candidate.name)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(L10n.vehiclePairingConfirm) {
                pairConnectedBluetooth(candidate: candidate)
            }
            .buttonStyle(.borderedProminent)
        } else {
            VStack(spacing: 8) {
                ProgressView()
                Text(L10n.vehiclePairingWaitingBluetooth)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button(L10n.actionRefresh) {
                bluetoothService.syncRouteSnapshot()
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var carPlaySection: some View {
        Group {
            if CarPlayConnectionHandler.shared.isConnected {
                VStack(spacing: 8) {
                    Text(L10n.vehiclePairingCarPlayConnected)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("CarPlay")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(L10n.vehiclePairingConfirm) {
                    pairCarPlay()
                }
                .buttonStyle(.borderedProminent)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "cable.connector")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(L10n.vehiclePairingCarPlayHint)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button(L10n.actionRefresh) {
                    carPlayRefreshToken += 1
                }
                .buttonStyle(.bordered)
            }
        }
        .id(carPlayRefreshToken)
    }

    private func savedVehicleSubtitle(_ vehicle: VehicleProfile) -> String {
        switch vehicle.connectionKind {
        case .bluetooth:
            return vehicle.connectionDisplayName ?? L10n.vehiclePairingBluetooth
        case .carPlay:
            return L10n.vehiclePairingCarPlay
        case .none:
            return L10n.vehiclePairingNoConnection
        }
    }

    private func pairSavedVehicle(_ vehicle: VehicleProfile) {
        switch vehicle.connectionKind {
        case .bluetooth:
            guard let identifier = vehicle.connectionIdentifier else {
                AppErrorPresenter.shared.present(L10n.vehiclePairingMissingConnection)
                return
            }
            VehiclePairingService.pair(
                vehicle: vehicle,
                kind: .bluetooth,
                identifier: identifier,
                displayName: vehicle.connectionDisplayName ?? vehicle.name,
                in: modelContext
            )
        case .carPlay:
            VehiclePairingService.pair(
                vehicle: vehicle,
                kind: .carPlay,
                identifier: VehicleConnectionKind.carPlayVehicleID,
                displayName: vehicle.connectionDisplayName ?? "CarPlay",
                in: modelContext
            )
        case .none:
            AppErrorPresenter.shared.present(L10n.vehiclePairingMissingConnection)
            return
        }
        settings.hasCompletedCarSetup = true
        dismiss()
    }

    private func pairConnectedBluetooth(candidate: (id: String, name: String)) {
        let vehicle = targetVehicle(named: candidate.name)
        VehiclePairingService.pair(
            vehicle: vehicle,
            kind: .bluetooth,
            identifier: candidate.id,
            displayName: candidate.name,
            in: modelContext
        )
        settings.hasCompletedCarSetup = true
        dismiss()
    }

    private func pairCarPlay() {
        let vehicle = targetVehicle(named: "CarPlay")
        VehiclePairingService.pair(
            vehicle: vehicle,
            kind: .carPlay,
            identifier: VehicleConnectionKind.carPlayVehicleID,
            displayName: "CarPlay",
            in: modelContext
        )
        settings.hasCompletedCarSetup = true
        dismiss()
    }

    private func targetVehicle(named name: String) -> VehicleProfile {
        if let existing = sortedVehicles.first(where: {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }) {
            return existing
        }
        let vehicle = VehicleProfile(
            name: name,
            consumption: settings.fuelLitersPer100km,
            isDefault: vehicles.isEmpty
        )
        modelContext.insert(vehicle)
        return vehicle
    }
}

#Preview {
    CarPairingSheet()
        .environment(BluetoothTriggerService())
        .modelContainer(PreviewData.shared.container)
}
