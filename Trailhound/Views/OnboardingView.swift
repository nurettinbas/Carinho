import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case location
    case shortcuts
    case vehicle

    static var count: Int { allCases.count }
}

struct OnboardingView: View {
    @Environment(LocationService.self) private var locationService
    @Bindable private var settings = AppSettings.shared
    @Bindable private var tabSelection = TabSelection.shared

    @State private var page = OnboardingStep.welcome.rawValue
    @State private var showShortcutsAutomationGuide = false

    private var pageCount: Int { OnboardingStep.count }

    var body: some View {
        ZStack {
            AtmosphericBackground()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    welcomePage
                        .tag(OnboardingStep.welcome.rawValue)
                    locationPage
                        .tag(OnboardingStep.location.rawValue)
                    shortcutsPage
                        .tag(OnboardingStep.shortcuts.rawValue)
                    vehiclePage
                        .tag(OnboardingStep.vehicle.rawValue)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(TrailhoundMotion.gentle, value: page)

                pageIndicator
                    .padding(.top, 8)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showShortcutsAutomationGuide) {
            PairingShortcutsAutomationGuideView()
        }
    }

    // MARK: - Pages

    private var welcomePage: some View {
        onboardingHeroPage(
            icon: "car.side.fill",
            title: L10n.string("onboarding.welcome.title"),
            message: L10n.string("onboarding.welcome.message")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                onboardingFeatureRow(
                    icon: "antenna.radiowaves.left.and.right",
                    text: L10n.string("onboarding.features.auto")
                )
                onboardingFeatureRow(
                    icon: "point.topleft.down.curvedto.point.bottomright.up",
                    text: L10n.string("onboarding.features.routes")
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

    private var locationPage: some View {
        onboardingHeroPage(
            icon: "location.fill",
            title: L10n.string("onboarding.location.title"),
            message: L10n.string("onboarding.location.message")
        ) {
            VStack(spacing: 12) {
                LocationPermissionBadge(state: locationService.authorizationState)

                locationPermissionActions
            }
        }
    }

    private var shortcutsPage: some View {
        onboardingHeroPage(
            icon: "bolt.horizontal.circle.fill",
            title: L10n.string("onboarding.shortcuts.title"),
            message: L10n.string("onboarding.shortcuts.message")
        ) {
            Button {
                showShortcutsAutomationGuide = true
                TrailhoundHaptics.selection()
            } label: {
                HStack(spacing: 6) {
                    Text(L10n.string("onboarding.shortcuts.link"))
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                }
                .font(.body.weight(.semibold))
            }
            .foregroundStyle(TrailhoundBrandColors.brandBottom)
            .padding(.top, 4)
        }
    }

    private var vehiclePage: some View {
        onboardingHeroPage(
            icon: "link.circle",
            title: L10n.string("onboarding.vehicle.title"),
            message: L10n.string("onboarding.vehicle.message")
        ) {
            VStack(spacing: 12) {
                Button(action: defineVehicleAndFinish) {
                    Text(L10n.string("onboarding.vehicle.define"))
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(TrailhoundBrandColors.brandBottom)

                Button(action: skipVehicleSetup) {
                    Text(L10n.string("onboarding.vehicle.skip"))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Building blocks

    private func onboardingHeroPage<Extra: View>(
        icon: String,
        title: String,
        message: String? = nil,
        @ViewBuilder extra: () -> Extra = { EmptyView() }
    ) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(TrailhoundBrandColors.brandBottom)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if let message {
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 8)

            extra()

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private func onboardingFeatureRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(TrailhoundBrandColors.brandBottom)
                .frame(width: 28, alignment: .center)

            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var locationPermissionActions: some View {
        switch locationService.authorizationState {
        case .authorizedAlways:
            Text(L10n.string("onboarding.permission.granted"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        case .denied, .restricted:
            Button(L10n.locationBannerSettings) {
                openAppSettings()
            }
            .buttonStyle(.borderedProminent)
            .tint(TrailhoundBrandColors.brandBottom)
        case .notDetermined, .authorizedWhenInUse:
            Button(L10n.string("onboarding.location.enable_always")) {
                locationService.requestPermission()
                TrailhoundHaptics.selection()
            }
            .buttonStyle(.borderedProminent)
            .tint(TrailhoundBrandColors.brandBottom)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == page ? Color.primary : Color.secondary.opacity(0.25))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: L10n.string("onboarding.step_a11y"), page + 1, pageCount))
    }

    private var bottomBar: some View {
        HStack {
            if page > 0 {
                Button(L10n.string("onboarding.back")) {
                    withAnimation(TrailhoundMotion.gentle) {
                        page -= 1
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if page < OnboardingStep.vehicle.rawValue {
                Button(L10n.string("onboarding.next")) {
                    withAnimation(TrailhoundMotion.gentle) {
                        page += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(TrailhoundBrandColors.brandBottom)
            }
        }
    }

    // MARK: - Actions

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func defineVehicleAndFinish() {
        settings.completeOnboarding()
        TrailhoundHaptics.selection()
        DispatchQueue.main.async {
            tabSelection.openPairing()
        }
    }

    private func skipVehicleSetup() {
        settings.completeOnboarding()
        settings.skipCarSetup()
        TrailhoundHaptics.selection()
    }
}

#Preview {
    OnboardingView()
        .environment(LocationService())
}
