import SwiftData
import SwiftUI

struct VehicleManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var vehicles: [VehicleProfile]
    @Bindable private var settings = AppSettings.shared
    @FocusState.Binding var focusedField: SettingsFocusedField?

    @State private var newVehicleName = ""

    private var sortedVehicles: [VehicleProfile] {
        vehicles.sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault { return lhs.isDefault }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    var body: some View {
        Section("Araçlar") {
            ForEach(sortedVehicles, id: \.id) { vehicle in
                NavigationLink {
                    VehicleEditorView(vehicle: vehicle, focusedField: $focusedField)
                } label: {
                    HStack {
                        Image(systemName: vehicle.fuelType == .electric ? "bolt.car.fill" : "car.fill")
                        VStack(alignment: .leading) {
                            Text(vehicle.name)
                            Text(vehicleSummary(vehicle))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if vehicle.isDefault {
                            Spacer()
                            Text("Varsayılan")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteVehicles)

            HStack {
                TextField("Yeni araç", text: $newVehicleName)
                    .focused($focusedField, equals: .newVehicle)
                Button("Ekle") { addVehicle() }
                    .disabled(newVehicleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        if settings.fuelLitersPer100km > 0 || vehicles.isEmpty {
            Section("EV şarj fiyatı") {
                LabeledContent("kWh fiyatı") {
                    TextField("TL/kWh", value: $settings.evChargePricePerKWh, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .evChargePrice)
                }
            }
        }
    }

    private func vehicleSummary(_ vehicle: VehicleProfile) -> String {
        let consumption = String(format: "%.1f %@", vehicle.consumption, vehicle.consumptionLabel)
        if vehicle.hasAutoTriggerConnection {
            return "\(vehicle.fuelType.displayName) · \(consumption) · \(L10n.vehicleAutoTrigger)"
        }
        return "\(vehicle.fuelType.displayName) · \(consumption)"
    }

    private func addVehicle() {
        let name = newVehicleName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let isFirst = vehicles.isEmpty
        let vehicle = VehicleProfile(
            name: name,
            fuelType: .petrol,
            consumption: settings.fuelLitersPer100km,
            isDefault: isFirst
        )
        modelContext.insert(vehicle)
        try? modelContext.save()
        newVehicleName = ""
    }

    private func deleteVehicles(at offsets: IndexSet) {
        let targets = offsets.map { sortedVehicles[$0] }
        for vehicle in targets {
            modelContext.delete(vehicle)
        }
        try? modelContext.save()
    }
}

struct VehicleEditorView: View {
    @Bindable var vehicle: VehicleProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @FocusState.Binding var focusedField: SettingsFocusedField?

    @State private var autoTriggerEnabled = false
    @State private var selectedConnectionKind: VehicleConnectionKind = .none

    var body: some View {
        Form {
            Section("Araç") {
                TextField("Ad", text: $vehicle.name)
                Picker("Yakıt tipi", selection: Binding(
                    get: { vehicle.fuelType },
                    set: { vehicle.fuelType = $0 }
                )) {
                    ForEach(VehicleFuelType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                LabeledContent(vehicle.consumptionLabel) {
                    TextField(vehicle.consumptionLabel, value: $vehicle.consumption, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .vehicleConsumption)
                }
                if vehicle.fuelType == .electric {
                    LabeledContent("Şarj fiyatı") {
                        TextField("TL/kWh", value: Binding(
                            get: { vehicle.chargePricePerKWh ?? AppSettings.shared.evChargePricePerKWh },
                            set: { vehicle.chargePricePerKWh = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .evChargePrice)
                    }
                }
                Toggle("Varsayılan araç", isOn: $vehicle.isDefault)
                    .onChange(of: vehicle.isDefault) { _, isDefault in
                        if isDefault { clearOtherDefaults() }
                    }
            }

            Section(L10n.vehicleAutoTrigger) {
                Toggle(L10n.vehicleAutoTrigger, isOn: $autoTriggerEnabled)
                if autoTriggerEnabled {
                    Picker(L10n.settingsConnectionType, selection: $selectedConnectionKind) {
                        Text(L10n.vehiclePairingBluetooth).tag(VehicleConnectionKind.bluetooth)
                        Text(L10n.vehiclePairingCarPlay).tag(VehicleConnectionKind.carPlay)
                    }
                    if selectedConnectionKind == .bluetooth, let name = vehicle.connectionDisplayName {
                        LabeledContent(L10n.settingsPairedVehicle, value: name)
                    }
                }
            }

            Section {
                Button("Kaydet") {
                    applyAutoTriggerSettings()
                    if vehicle.isDefault { clearOtherDefaults() }
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .navigationTitle(vehicle.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            autoTriggerEnabled = vehicle.hasAutoTriggerConnection
            selectedConnectionKind = vehicle.connectionKind == .none ? .carPlay : vehicle.connectionKind
        }
    }

    private func applyAutoTriggerSettings() {
        if autoTriggerEnabled {
            switch selectedConnectionKind {
            case .carPlay:
                VehiclePairingService.pair(
                    vehicle: vehicle,
                    kind: .carPlay,
                    identifier: AppSettings.carPlayVehicleID,
                    displayName: vehicle.connectionDisplayName ?? "CarPlay",
                    in: modelContext
                )
            case .bluetooth:
                guard let identifier = vehicle.connectionIdentifier else {
                    vehicle.connectionKind = .bluetooth
                    vehicle.syncLegacyConnectionFields()
                    return
                }
                VehiclePairingService.pair(
                    vehicle: vehicle,
                    kind: .bluetooth,
                    identifier: identifier,
                    displayName: vehicle.connectionDisplayName ?? vehicle.name,
                    in: modelContext
                )
            case .none:
                break
            }
        } else if AppSettings.shared.activeAutoTriggerVehicleID == vehicle.id {
            VehiclePairingService.unpair(in: modelContext)
            vehicle.connectionKind = .none
            vehicle.syncLegacyConnectionFields()
        } else {
            vehicle.connectionKind = .none
            vehicle.syncLegacyConnectionFields()
        }
    }

    private func clearOtherDefaults() {
        let descriptor = FetchDescriptor<VehicleProfile>()
        let all = (try? modelContext.fetch(descriptor)) ?? []
        for other in all where other.id != vehicle.id {
            other.isDefault = false
        }
    }
}
