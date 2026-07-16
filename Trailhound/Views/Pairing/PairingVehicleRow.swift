import SwiftUI

struct PairingVehicleRow: View {
    let vehicle: VehicleProfile
    let isAutoStartActive: Bool
    let subtitle: String
    let showsAutoStartButton: Bool
    let onOpen: () -> Void
    let onAutoStart: () -> Void
    let onRemoveAutoStart: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .center, spacing: 12) {
                    vehicleIcon

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(vehicle.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if isAutoStartActive {
                                Text(L10n.pairingTabActiveBadge)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            trailingAction
        }
    }

    @ViewBuilder
    private var trailingAction: some View {
        if showsAutoStartButton {
            Button(action: onAutoStart) {
                Text(L10n.pairingAutoStart)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(TrailhoundBrandColors.brandBottom)
        } else if isAutoStartActive {
            Button(L10n.pairingTabRemovePairing, role: .destructive, action: onRemoveAutoStart)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private var vehicleIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(vehicle.fuelType == .electric
                    ? Color.yellow.opacity(0.15)
                    : TrailhoundBrandColors.brandBottom.opacity(0.12))
                .frame(width: 36, height: 36)
            Image(systemName: vehicle.fuelType == .electric ? "bolt.car.fill" : "car.fill")
                .font(.body)
                .foregroundStyle(vehicle.fuelType == .electric ? .yellow : TrailhoundBrandColors.brandBottom)
        }
    }
}
