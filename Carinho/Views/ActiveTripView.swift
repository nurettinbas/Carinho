import SwiftUI

struct ActiveTripView: View {
    @Environment(TripRecordingService.self) private var recordingService
    @Environment(LocationService.self) private var locationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: statusIcon)
                        .font(.subheadline)
                        .foregroundStyle(statusColor)
                        .symbolEffect(.pulse, options: .repeating, isActive: !isPaused && !reduceMotion)
                    Text(statusText)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 4)

                GPSQualityBadge(quality: locationService.gpsQuality)
            }
            .animation(reduceMotion ? nil : CarinhoMotion.gentle, value: statusText)

            RecordingCarAnimationView(compact: true, isAnimating: !isPaused)

            HStack(alignment: .top, spacing: 8) {
                statPill(icon: "clock.fill", label: L10n.duration, text: elapsedText)
                statPill(icon: "speedometer", label: L10n.currentSpeed, text: speedText)
                statPill(icon: "location.fill", label: L10n.string("label.distance"), text: distanceText)
            }

            HStack(spacing: 8) {
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
                .controlSize(.small)
                .tint(.white)

                Button(role: .destructive) {
                    recordingService.stopManualRecording()
                } label: {
                    Text(L10n.stop)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.red)
            }
        }
        .padding(14)
        .background(RecordingCardStyle.background(isPaused: isPaused))
        .animation(reduceMotion ? nil : CarinhoMotion.gentle, value: isPaused)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var statusIcon: String {
        isPaused ? "pause.circle.fill" : "record.circle.fill"
    }

    private var statusColor: Color {
        isPaused ? .yellow : .red
    }

    private var accessibilitySummary: String {
        let format = L10n.string("recording.accessibility.summary")
        return String(format: format, statusText, elapsedText, speedText, distanceText)
    }

    private func statPill(icon: String, label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .numericTextAnimation(value: text)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(text)")
    }
}

#Preview {
    ActiveTripView()
        .environment(PreviewData.shared.recordingService)
        .environment(LocationService())
}
