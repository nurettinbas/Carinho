import Foundation

public enum AutoRecordingEventChannel: String, Codable, Sendable {
    case bluetooth
    case motion
}

public enum AutoRecordingEventKind: String, Codable, Sendable {
    case connectStarted
    case connectAwaitingGPS
    case connectCancelled
    case connectSkipped
    case disconnectStopped
    case disconnectSkipped
    case motionStarted
    case motionStopped
}

public struct StoredAutoRecordingEvent: Codable, Identifiable, Sendable {
    public let id: UUID
    public let triggerAt: Date
    public let kind: String
    public let channel: String
    public let vehicleName: String?
    public let actionAt: Date?
    public let delaySeconds: Int?
    public let distanceMeters: Double?

    public init(
        id: UUID = UUID(),
        triggerAt: Date,
        kind: AutoRecordingEventKind,
        channel: AutoRecordingEventChannel,
        vehicleName: String? = nil,
        actionAt: Date? = nil,
        delaySeconds: Int? = nil,
        distanceMeters: Double? = nil
    ) {
        self.id = id
        self.triggerAt = triggerAt
        self.kind = kind.rawValue
        self.channel = channel.rawValue
        self.vehicleName = vehicleName
        self.actionAt = actionAt
        self.delaySeconds = delaySeconds
        self.distanceMeters = distanceMeters
    }
}

public enum AutoRecordingEventArchive {
    private static let storageKey = "auto.recording.eventLog"
    private static let maxCount = 50

    public static func load() -> [StoredAutoRecordingEvent] {
        guard let data = RecordingControlBridge.sharedDefaults().data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([StoredAutoRecordingEvent].self, from: data)) ?? []
    }

    public static func save(_ items: [StoredAutoRecordingEvent]) {
        let trimmed = Array(items.prefix(maxCount))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        RecordingControlBridge.sharedDefaults().set(data, forKey: storageKey)
    }

    public static func clear() {
        RecordingControlBridge.sharedDefaults().removeObject(forKey: storageKey)
    }
}
