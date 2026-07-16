import SwiftData
import SwiftUI

struct PairingVehicleEditorView: View {
    let vehicleID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var vehicles: [VehicleProfile]

    private var vehicle: VehicleProfile? {
        vehicles.first { $0.id == vehicleID }
    }

    var body: some View {
        Group {
            if let vehicle {
                PairingVehicleEditorForm(vehicle: vehicle)
            } else {
                ContentUnavailableView(L10n.pairingTabVehicleNotFound, systemImage: "car")
            }
        }
        .onChange(of: vehicle?.id) { _, newID in
            if newID == nil {
                dismiss()
            }
        }
    }
}

private struct PairingVehicleEditorForm: View {
    @Bindable var vehicle: VehicleProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section(L10n.pairingTabVehicleSection) {
                TextField(L10n.pairingTabVehicleName, text: $vehicle.name)
                Picker(L10n.pairingTabFuelType, selection: Binding(
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
                }
                if vehicle.fuelType == .electric {
                    LabeledContent(L10n.pairingTabChargePrice) {
                        TextField("TL/kWh", value: Binding(
                            get: { vehicle.chargePricePerKWh ?? settings.evChargePricePerKWh },
                            set: { vehicle.chargePricePerKWh = $0 }
                        ), format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    }
                }
            }

            Section {
                Text(L10n.pairingTabEditorPairingHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(L10n.pairingTabSave) {
                    do {
                        try modelContext.save()
                        dismiss()
                    } catch {
                        AppErrorPresenter.shared.present(L10n.pairingTabSaveFailed(error.localizedDescription))
                    }
                }
            }
        }
        .navigationTitle(vehicle.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
