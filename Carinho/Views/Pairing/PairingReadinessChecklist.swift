import SwiftUI

struct PairingReadinessChecklist: View {
    @Environment(LocationService.self) private var locationService
    @Environment(MotionActivityService.self) private var motionActivityService
    @Environment(BluetoothTriggerService.self) private var bluetoothService
    @Bindable private var settings = AppSettings.shared

    let activeVehicle: VehicleProfile?
    let refreshToken: Int

    private var isLocationAlwaysReady: Bool {
        locationService.authorizationState == .authorizedAlways
    }

    private var isMotionReady: Bool {
        !motionActivityService.isActivityAvailable || motionActivityService.isAuthorized
    }

    private var isVehiclePaired: Bool {
        settings.hasAutoTriggerVehicle
    }

    private var isConnectionDetected: Bool {
        PairingConnectionStatus.isConnectionCurrentlyDetected(
            pairedVehicle: activeVehicle,
            settings: settings,
            bluetoothService: bluetoothService
        )
    }

    private var isAutoRecordingEnabled: Bool {
        settings.autoRecordingEnabled
    }

    private var incompleteItems: [(label: String, isReady: Bool)] {
        _ = refreshToken
        let all: [(String, Bool)] = [
            (L10n.pairingReadinessLocationAlways, isLocationAlwaysReady),
            (L10n.pairingReadinessMotion, isMotionReady),
            (L10n.pairingReadinessVehiclePaired, isVehiclePaired),
            (L10n.pairingReadinessConnectionDetected, isConnectionDetected),
            (L10n.pairingReadinessAutoRecording, isAutoRecordingEnabled),
        ]
        return all.filter { !$0.1 }
    }

    var body: some View {
        if !incompleteItems.isEmpty {
            PairingCardContainer {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.pairingReadinessTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    ForEach(Array(incompleteItems.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Divider().padding(.leading, 12)
                        }
                        readinessRow(label: item.label, isReady: item.isReady)
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(L10n.pairingReadinessTitle)
        }
    }

    private func readinessRow(label: String, isReady: Bool) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Image(systemName: isReady ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.body)
                .foregroundStyle(isReady ? .green : .red)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(isReady ? L10n.pairingReadinessReady : L10n.pairingReadinessNotReady)
    }
}
