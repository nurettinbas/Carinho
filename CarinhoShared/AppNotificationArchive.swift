import Foundation

public struct StoredAppNotification: Codable, Identifiable, Sendable {
    public let id: UUID
    public let kind: String
    public let title: String
    public let body: String
    public let createdAt: Date
    public let tripID: UUID?
    public var isRead: Bool

    public init(
        id: UUID = UUID(),
        kind: String,
        title: String,
        body: String,
        createdAt: Date = Date(),
        tripID: UUID? = nil,
        isRead: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.createdAt = createdAt
        self.tripID = tripID
        self.isRead = isRead
    }
}

public enum AppNotificationArchive {
    private static let storageKey = "app.notifications.inbox"
    private static let maxCount = 100
    public static func load() -> [StoredAppNotification] {
        guard let data = RecordingControlBridge.sharedDefaults().data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([StoredAppNotification].self, from: data)) ?? []
    }

    public static func save(_ items: [StoredAppNotification]) {
        let trimmed = Array(items.prefix(maxCount))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        RecordingControlBridge.sharedDefaults().set(data, forKey: storageKey)
    }

    public static func append(
        kind: String,
        title: String,
        body: String,
        tripID: UUID? = nil,
        createdAt: Date = Date()
    ) {
        var items = load()
        let record = StoredAppNotification(
            kind: kind,
            title: title,
            body: body,
            createdAt: createdAt,
            tripID: tripID
        )
        items.insert(record, at: 0)
        save(items)
    }

}
