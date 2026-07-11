import SwiftUI

struct PairingEmptyState: View {
    let onAddVehicle: () -> Void

    var body: some View {
        PairingCardContainer {
            VStack(spacing: 14) {
                Image(systemName: "car.fill")
                    .font(.title2)
                    .foregroundStyle(CarinhoBrandColors.brandBottom)
                    .symbolRenderingMode(.hierarchical)

                VStack(spacing: 4) {
                    Text(L10n.pairingTabEmptyTitle)
                        .font(.headline)
                    Text(L10n.pairingTabEmptyMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: onAddVehicle) {
                    Label(L10n.pairingTabDefineVehicle, systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(CarinhoBrandColors.brandBottom)
            }
            .padding(16)
        }
    }
}
