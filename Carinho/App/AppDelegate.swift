import AppIntents
import CarPlay
@preconcurrency import UserNotifications
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        CarinhoShortcuts.updateAppShortcutParameters()
        Task { @MainActor in
            AppServices.bootstrapRecordingIfNeeded()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .carTemplateApplication {
            let configuration = UISceneConfiguration(
                name: "CarPlay Configuration",
                sessionRole: connectingSceneSession.role
            )
            configuration.delegateClass = CarPlaySceneDelegate.self
            configuration.sceneClass = CPTemplateApplicationScene.self
            return configuration
        }

        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        return configuration
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        if !isAlreadyRecordedInInbox(notification.request.content.userInfo) {
            let title = notification.request.content.title
            let body = notification.request.content.body
            let identifier = notification.request.identifier
            AppNotificationStore.enqueueSystemNotification(
                title: title,
                body: body,
                identifier: identifier
            )
        }
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if !isAlreadyRecordedInInbox(response.notification.request.content.userInfo) {
            let title = response.notification.request.content.title
            let body = response.notification.request.content.body
            let identifier = response.notification.request.identifier
            AppNotificationStore.enqueueSystemNotification(
                title: title,
                body: body,
                identifier: identifier
            )
        } else {
            Task { @MainActor in
                AppNotificationStore.shared.reload()
            }
        }
        completionHandler()
    }

    nonisolated private func isAlreadyRecordedInInbox(_ userInfo: [AnyHashable: Any]) -> Bool {
        userInfo["carinho.inboxRecorded"] as? Bool == true
    }
}
