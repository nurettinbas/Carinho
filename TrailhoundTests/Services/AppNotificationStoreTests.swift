import XCTest
@testable import Trailhound

@MainActor
final class AppNotificationStoreTests: XCTestCase {
    private let store = AppNotificationStore.shared

    override func setUp() {
        AppNotificationArchive.save([])
        store.reload()
        store.clearAll()
    }

    func testRecordIncrementsUnreadCount() {
        store.record(kind: .tripStarted, title: "Started", body: "Recording")

        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.unreadCount, 1)
    }

    func testMarkReadDecrementsUnreadCount() {
        store.record(kind: .tripEnded, title: "Ended", body: "Done")
        let id = store.items[0].id

        store.markRead(id)

        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertTrue(store.items[0].isRead)
    }

    func testDeleteRemovesItem() {
        store.record(kind: .tripDiscarded, title: "Discarded", body: "Removed")
        let id = store.items[0].id

        store.delete(id)

        XCTAssertTrue(store.items.isEmpty)
    }

    func testClearAllRemovesAllItems() {
        store.record(kind: .tripStarted, title: "A", body: "1")
        store.record(kind: .tripEnded, title: "B", body: "2")

        store.clearAll()

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(AppNotificationArchive.load().count, 0)
    }

    func testArchiveRoundTrip() {
        let record = StoredAppNotification(
            kind: AppNotificationKind.pairingSuggestion.rawValue,
            title: "Pair",
            body: "Suggestion"
        )
        AppNotificationArchive.save([record])

        let loaded = AppNotificationArchive.load()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].title, "Pair")
    }
}
