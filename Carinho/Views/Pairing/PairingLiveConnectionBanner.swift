import SwiftUI

struct PairingLiveConnectionBanner: View {
    let bluetoothService: BluetoothTriggerService
    let refreshToken: Int

    @Environment(\.colorScheme) private var colorScheme

    private var liveConnection: LiveVehicleConnection {
        VehiclePairingService.detectLiveConnection(bluetoothService: bluetoothService)
    }

    var body: some View {
        PairingCardContainer {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(liveConnection.isDetected ? Color.green.opacity(0.15) : Color.secondary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: liveConnection.isDetected ? "checkmark.circle.fill" : "car.side")
                        .font(.title3)
                        .foregroundStyle(liveConnection.isDetected ? .green : .secondary)
                        .symbolRenderingMode(.hierarchical)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.pairingLiveConnectionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    if liveConnection.isDetected {
                        Text(liveConnection.displayLabel())
                            .font(.headline)
                            .lineLimit(2)
                        Text(L10n.pairingAutoStartHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(L10n.pairingLiveConnectionNone)
                            .font(.headline)
                        Text(L10n.pairingTabWaitingConnection)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
        .id(refreshToken)
    }
}
