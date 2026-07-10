import SwiftUI

struct ActiveTripView: View {
    @Environment(TripRecordingService.self) private var recordingService
    @Environment(LocationService.self) private var locationService

    private var isPaused: Bool {
        recordingService.state == .paused
    }

    private var speedText: String {
        let kmh = Int(max(0, recordingService.currentSpeedMps) * 3.6)
        return "\(kmh) \(L10n.speedKmh)"
    }

    private var elapsedText: String {
        DateFormatters.formatDuration(recordingService.elapsedTime)
    }

    private var distanceText: String {
        DateFormatters.formatDistance(recordingService.currentDistanceMeters)
    }

    private var statusText: String {
        isPaused ? L10n.recordingPaused : L10n.recordingStarted
    }

    var body: some View {
        if recordingService.state.isActiveSession {
            recordingCard
        } else {
            EmptyView()
        }
    }

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(statusText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                Spacer(minLength: 4)
                GPSQualityBadge(quality: locationService.gpsQuality)
                Image(systemName: isPaused ? "pause.circle.fill" : "record.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isPaused ? .yellow : .red)
                    .accessibilityHidden(true)
            }

            RecordingCarAnimationView(compact: true, isAnimating: !isPaused)
                .id(isPaused)

            HStack(spacing: 0) {
                statItem(icon: "clock.fill", label: L10n.duration, text: elapsedText)
                divider
                statItem(icon: "speedometer", label: L10n.currentSpeed, text: speedText)
                divider
                statItem(icon: "location.fill", label: L10n.string("label.distance"), text: distanceText)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 10) {
                Button {
                    if isPaused {
                        recordingService.resumeRecording()
                    } else {
                        recordingService.pauseRecording()
                    }
                } label: {
                    Label(isPaused ? L10n.resume : L10n.pause, systemImage: isPaused ? "play.fill" : "pause.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .tint(.white)

                Button(role: .destructive) {
                    recordingService.stopManualRecording()
                } label: {
                    Text(L10n.stop)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(.red)
            }
        }
        .padding(16)
        .background(RecordingCardStyle.background(isPaused: isPaused))
        .animation(.easeInOut(duration: 0.25), value: isPaused)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let format = L10n.string("recording.accessibility.summary")
        return String(format: format, statusText, elapsedText, speedText, distanceText)
    }

    private func statItem(icon: String, label: String, text: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Text(text)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(text)")
    }

    private var divider: some View {
        Text("·")
            .font(.title3)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.horizontal, 2)
            .accessibilityHidden(true)
    }
}

#Preview {
    ActiveTripView()
        .environment(PreviewData.shared.recordingService)
        .environment(LocationService())
}
