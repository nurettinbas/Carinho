import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @Environment(LocationService.self) private var locationService
    @Environment(MotionActivityService.self) private var motionActivityService
    @Bindable private var settings = AppSettings.shared

    @State private var page = 0
    @State private var notificationsAuthorized = false

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                locationPage.tag(0)
                motionPage.tag(1)
                notificationsPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(CarinhoMotion.gentle, value: page)

            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            motionActivityService.refreshAuthorizationStatus()
            refreshNotificationStatus()
        }
    }

    private var locationPage: some View {
        OnboardingPermissionPage(
            systemImage: "location.fill",
            tint: .blue,
            title: L10n.string("onboarding.location.title"),
            message: L10n.string("onboarding.location.message"),
            isGranted: locationService.authorizationState == .authorizedAlways,
            actionTitle: {
                switch locationService.authorizationState {
                case .authorizedAlways:
                    L10n.string("onboarding.permission.granted")
                case .authorizedWhenInUse:
                    L10n.string("onboarding.location.enable_always")
                default:
                    L10n.string("onboarding.permission.allow")
                }
            },
            action: { locationService.requestPermission() }
        )
    }

    private var motionPage: some View {
        OnboardingPermissionPage(
            systemImage: "figure.walk.motion",
            tint: .purple,
            title: L10n.string("onboarding.motion.title"),
            message: L10n.string("onboarding.motion.message"),
            isGranted: motionActivityService.isAuthorized,
            actionTitle: {
                motionActivityService.isAuthorized
                    ? L10n.string("onboarding.permission.granted")
                    : L10n.string("onboarding.permission.allow")
            },
            action: { motionActivityService.requestPermission() }
        )
    }

    private var notificationsPage: some View {
        OnboardingPermissionPage(
            systemImage: "bell.badge.fill",
            tint: .orange,
            title: L10n.string("onboarding.notifications.title"),
            message: L10n.string("onboarding.notifications.message"),
            isGranted: notificationsAuthorized,
            actionTitle: {
                notificationsAuthorized
                    ? L10n.string("onboarding.permission.granted")
                    : L10n.string("onboarding.permission.allow")
            },
            action: { requestNotifications() }
        )
    }

    private var bottomBar: some View {
        HStack {
            if page > 0 {
                Button(L10n.string("onboarding.back")) {
                    page -= 1
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button(page == pageCount - 1 ? L10n.string("onboarding.finish") : L10n.string("onboarding.next")) {
                if page == pageCount - 1 {
                    settings.hasCompletedOnboarding = true
                } else {
                    page += 1
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { notificationSettings in
            let isAuthorized = notificationSettings.authorizationStatus == .authorized
            Task { @MainActor in
                notificationsAuthorized = isAuthorized
            }
        }
    }

    private func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            Task { @MainActor in
                notificationsAuthorized = granted
            }
        }
    }
}

private struct OnboardingPermissionPage: View {
    let systemImage: String
    let tint: Color
    let title: String
    let message: String
    let isGranted: Bool
    let actionTitle: () -> String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .scaleEffect(iconScale)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            if isGranted {
                Label(L10n.string("onboarding.permission.granted"), systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button(actionTitle(), action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
            }

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .animation(reduceMotion ? nil : CarinhoMotion.cardSpring, value: isGranted)
        .onChange(of: isGranted) { wasGranted, isNowGranted in
            guard !wasGranted, isNowGranted else { return }
            CarinhoHaptics.selection()
            if !reduceMotion {
                withAnimation(CarinhoMotion.cardSpring) {
                    iconScale = 1.08
                }
                withAnimation(CarinhoMotion.cardSpring.delay(0.15)) {
                    iconScale = 1
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environment(LocationService())
        .environment(MotionActivityService())
}
