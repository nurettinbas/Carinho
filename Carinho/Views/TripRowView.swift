import SwiftUI

struct TripRowView: View {
    let trip: Trip
    var places: [SavedPlace] = []
    var privacyRadius: Double = 500

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var thumbnail: UIImage?
    @State private var thumbnailLoaded = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnailView

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(TripListViewModel.dateText(for: trip))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if trip.categoryID == BuiltInCategory.businessID.uuidString {
                        Image(systemName: "briefcase.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                Text(TripListViewModel.routeSummary(for: trip, places: places, privacyRadius: privacyRadius))
                    .font(.headline)
                    .lineLimit(2)

                if let label = trip.label, !label.isEmpty {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    statLabel(icon: "clock", text: TripListViewModel.durationText(for: trip))
                    statLabel(icon: "road.lanes", text: TripListViewModel.distanceText(for: trip))
                    if let fuel = TripListViewModel.fuelText(for: trip) {
                        statLabel(icon: "fuelpump", text: fuel)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let maxLabel = TripListViewModel.maxSpeedLabel(for: trip),
                   let avgLabel = TripListViewModel.averageSpeedLabel(for: trip) {
                    HStack(spacing: 10) {
                        statLabel(icon: "speedometer", text: maxLabel)
                        statLabel(icon: "gauge.with.dots.needle.33percent", text: avgLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else if let maxLabel = TripListViewModel.maxSpeedLabel(for: trip) {
                    statLabel(icon: "speedometer", text: maxLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let avgLabel = TripListViewModel.averageSpeedLabel(for: trip) {
                    statLabel(icon: "gauge.with.dots.needle.33percent", text: avgLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .task(id: trip.id) {
            thumbnailLoaded = false
            let image = await TripMapSnapshotCache.shared.snapshot(for: trip)
            if !reduceMotion {
                withAnimation(CarinhoMotion.gentle) {
                    thumbnail = image
                    thumbnailLoaded = true
                }
            } else {
                thumbnail = image
                thumbnailLoaded = true
            }
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        Group {
            if let thumbnail, thumbnailLoaded {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                ZStack {
                    Color.secondary.opacity(0.12)
                        .shimmer()
                    Image(systemName: "map")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.5)
        }
        .accessibilityHidden(true)
    }

    private func statLabel(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .labelStyle(.titleAndIcon)
    }
}

#Preview {
    List {
        TripRowView(trip: PreviewData.sampleTrip)
    }
}
