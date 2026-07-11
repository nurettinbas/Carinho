import Foundation
import Observation

@MainActor
@Observable
final class AutoRecordingEventLog {
    static let shared = AutoRecordingEventLog()

    private(set) var events: [StoredAutoRecordingEvent] = []

    private struct PendingTrigger {
        let at: Date
        let channel: AutoRecordingEventChannel
        let vehicleName: String?
    }

    private var pendingConnect: PendingTrigger?
    private var pendingDisconnect: PendingTrigger?

    private init() {
        reload()
    }

    func reload() {
        events = AutoRecordingEventArchive.load()
    }

    func clear() {
        AutoRecordingEventArchive.clear()
        events = []
        pendingConnect = nil
        pendingDisconnect = nil
    }

    func noteVehicleConnectTrigger(channel: AutoRecordingEventChannel, vehicleName: String?) {
        pendingConnect = PendingTrigger(at: Date(), channel: channel, vehicleName: vehicleName)
    }

    func noteVehicleDisconnectTrigger(channel: AutoRecordingEventChannel) {
        pendingDisconnect = PendingTrigger(at: Date(), channel: channel, vehicleName: nil)
    }

    func recordConnectAwaitingGPS(channel: AutoRecordingEventChannel, vehicleName: String?) {
        let trigger = pendingConnect ?? PendingTrigger(at: Date(), channel: channel, vehicleName: vehicleName)
        if pendingConnect == nil {
            pendingConnect = trigger
        }
        let actionAt = Date()
        append(
            StoredAutoRecordingEvent(
                triggerAt: trigger.at,
                kind: .connectAwaitingGPS,
                channel: trigger.channel,
                vehicleName: trigger.vehicleName ?? vehicleName,
                actionAt: actionAt,
                delaySeconds: delaySeconds(from: trigger.at, to: actionAt)
            )
        )
    }

    func recordConnectStarted(channel: AutoRecordingEventChannel, vehicleName: String?) {
        let trigger = pendingConnect ?? PendingTrigger(at: Date(), channel: channel, vehicleName: vehicleName)
        let actionAt = Date()
        append(
            StoredAutoRecordingEvent(
                triggerAt: trigger.at,
                kind: .connectStarted,
                channel: trigger.channel,
                vehicleName: trigger.vehicleName ?? vehicleName,
                actionAt: actionAt,
                delaySeconds: delaySeconds(from: trigger.at, to: actionAt)
            )
        )
        pendingConnect = nil
    }

    func recordConnectCancelled(channel: AutoRecordingEventChannel, vehicleName: String?) {
        let trigger = pendingConnect ?? PendingTrigger(at: Date(), channel: channel, vehicleName: vehicleName)
        let actionAt = Date()
        append(
            StoredAutoRecordingEvent(
                triggerAt: trigger.at,
                kind: .connectCancelled,
                channel: trigger.channel,
                vehicleName: trigger.vehicleName ?? vehicleName,
                actionAt: actionAt,
                delaySeconds: delaySeconds(from: trigger.at, to: actionAt)
            )
        )
        pendingConnect = nil
    }

    func recordConnectSkipped(channel: AutoRecordingEventChannel, vehicleName: String?) {
        let trigger = pendingConnect ?? PendingTrigger(at: Date(), channel: channel, vehicleName: vehicleName)
        append(
            StoredAutoRecordingEvent(
                triggerAt: trigger.at,
                kind: .connectSkipped,
                channel: trigger.channel,
                vehicleName: trigger.vehicleName ?? vehicleName
            )
        )
        pendingConnect = nil
    }

    func recordDisconnectStopped(channel: AutoRecordingEventChannel, distanceMeters: Double) {
        let trigger = pendingDisconnect ?? PendingTrigger(at: Date(), channel: channel, vehicleName: nil)
        let actionAt = Date()
        append(
            StoredAutoRecordingEvent(
                triggerAt: trigger.at,
                kind: .disconnectStopped,
                channel: trigger.channel,
                actionAt: actionAt,
                delaySeconds: delaySeconds(from: trigger.at, to: actionAt),
                distanceMeters: distanceMeters
            )
        )
        pendingDisconnect = nil
    }

    func recordDisconnectSkipped(channel: AutoRecordingEventChannel) {
        let trigger = pendingDisconnect ?? PendingTrigger(at: Date(), channel: channel, vehicleName: nil)
        append(
            StoredAutoRecordingEvent(
                triggerAt: trigger.at,
                kind: .disconnectSkipped,
                channel: trigger.channel
            )
        )
        pendingDisconnect = nil
    }

    func recordMotionStarted() {
        let now = Date()
        append(
            StoredAutoRecordingEvent(
                triggerAt: now,
                kind: .motionStarted,
                channel: .motion,
                actionAt: now,
                delaySeconds: 0
            )
        )
    }

    func recordMotionStopped(distanceMeters: Double) {
        let now = Date()
        append(
            StoredAutoRecordingEvent(
                triggerAt: now,
                kind: .motionStopped,
                channel: .motion,
                actionAt: now,
                delaySeconds: 0,
                distanceMeters: distanceMeters
            )
        )
    }

    private func append(_ event: StoredAutoRecordingEvent) {
        events.insert(event, at: 0)
        if events.count > 50 {
            events = Array(events.prefix(50))
        }
        AutoRecordingEventArchive.save(events)
    }

    private func delaySeconds(from triggerAt: Date, to actionAt: Date) -> Int {
        max(0, Int(actionAt.timeIntervalSince(triggerAt).rounded()))
    }
}
