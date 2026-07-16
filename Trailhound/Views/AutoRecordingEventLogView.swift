import SwiftUI

enum AutoRecordingEventFormatter {
    static func description(for event: StoredAutoRecordingEvent) -> String {
        let time = DateFormatters.tripTime.string(from: event.triggerAt)
        let channel = AutoRecordingEventChannel(rawValue: event.channel) ?? .bluetooth
        let kind = AutoRecordingEventKind(rawValue: event.kind) ?? .connectStarted
        let delay = event.delaySeconds ?? 0
        let vehicle = event.vehicleName

        switch (channel, kind) {
        case (.bluetooth, .connectStarted):
            return L10n.autoLogBluetoothConnectedStarted(time, vehicle, delay)
        case (.bluetooth, .connectAwaitingGPS):
            return L10n.autoLogBluetoothConnectedAwaitingGPS(time, vehicle, delay)
        case (.bluetooth, .connectCancelled):
            return L10n.autoLogBluetoothConnectedCancelled(time, vehicle)
        case (.bluetooth, .connectSkipped):
            return L10n.autoLogBluetoothConnectedSkipped(time, vehicle)
        case (.bluetooth, .disconnectStopped):
            let distance = formattedDistance(event.distanceMeters)
            return L10n.autoLogBluetoothDisconnectedStopped(time, delay, distance)
        case (.bluetooth, .disconnectSkipped):
            return L10n.autoLogBluetoothDisconnectedSkipped(time)

        case (.carPlay, .connectStarted):
            return L10n.autoLogCarPlayConnectedStarted(time, vehicle, delay)
        case (.carPlay, .connectAwaitingGPS):
            return L10n.autoLogCarPlayConnectedAwaitingGPS(time, vehicle, delay)
        case (.carPlay, .connectCancelled):
            return L10n.autoLogCarPlayConnectedCancelled(time, vehicle)
        case (.carPlay, .connectSkipped):
            return L10n.autoLogCarPlayConnectedSkipped(time, vehicle)
        case (.carPlay, .disconnectStopped):
            let distance = formattedDistance(event.distanceMeters)
            return L10n.autoLogCarPlayDisconnectedStopped(time, delay, distance)
        case (.carPlay, .disconnectSkipped):
            return L10n.autoLogCarPlayDisconnectedSkipped(time)

        case (.motion, .motionStarted):
            return L10n.autoLogMotionStarted(time)
        case (.motion, .motionStopped):
            let distance = formattedDistance(event.distanceMeters)
            return L10n.autoLogMotionStopped(time, distance)

        default:
            return time
        }
    }

    private static func formattedDistance(_ meters: Double?) -> String {
        guard let meters else { return "—" }
        return DateFormatters.formatDistance(meters)
    }
}

struct AutoRecordingEventLogSection: View {
    @Bindable private var log = AutoRecordingEventLog.shared

    var body: some View {
        Section {
            if log.events.isEmpty {
                Text(L10n.autoLogEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(log.events) { event in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: icon(for: event))
                            .font(.subheadline)
                            .foregroundStyle(tint(for: event))
                            .frame(width: 20)
                        Text(AutoRecordingEventFormatter.description(for: event))
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }

                Button(L10n.autoLogClear, role: .destructive) {
                    log.clear()
                }
            }
        } header: {
            Text(L10n.autoLogSectionTitle)
        } footer: {
            Text(L10n.autoLogSectionHint)
        }
        .onAppear {
            log.reload()
        }
    }

    private func icon(for event: StoredAutoRecordingEvent) -> String {
        switch AutoRecordingEventKind(rawValue: event.kind) {
        case .connectStarted, .motionStarted:
            "play.circle.fill"
        case .connectAwaitingGPS:
            "location.circle"
        case .connectCancelled, .connectSkipped, .disconnectSkipped:
            "minus.circle"
        case .disconnectStopped, .motionStopped:
            "stop.circle.fill"
        case .none:
            "circle"
        }
    }

    private func tint(for event: StoredAutoRecordingEvent) -> Color {
        switch AutoRecordingEventKind(rawValue: event.kind) {
        case .connectStarted, .motionStarted:
            .green
        case .connectAwaitingGPS:
            .yellow
        case .disconnectStopped, .motionStopped:
            .blue
        case .connectCancelled:
            .orange
        case .connectSkipped, .disconnectSkipped:
            .secondary
        case .none:
            .secondary
        }
    }
}
