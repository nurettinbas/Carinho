import SwiftUI

struct OnboardingView: View {
    @Bindable private var settings = AppSettings.shared
    @Bindable private var tabSelection = TabSelection.shared

    @State private var page = 0

    private let pageCount = 2

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch page {
                case 0:
                    welcomePage
                default:
                    vehicleSetupPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(CarinhoMotion.gentle, value: page)

            pageIndicator
                .padding(.top, 8)

            bottomBar
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "car.side.fill")
                .font(.system(size: 56))
                .foregroundStyle(CarinhoBrandColors.brandBottom)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text(L10n.string("onboarding.welcome.title"))
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(L10n.string("onboarding.welcome.message"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var vehicleSetupPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.string("onboarding.vehicle.title"))
                    .font(.title2.bold())

                Text(L10n.string("onboarding.vehicle.message"))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: defineVehicleAndFinish) {
                    Text(L10n.string("onboarding.vehicle.define"))
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(CarinhoBrandColors.brandBottom)

                Button(action: skipVehicleSetup) {
                    Text(L10n.string("onboarding.vehicle.skip"))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
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
        .accessibilityLabel("Step \(page + 1) of \(pageCount)")
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

            if page < pageCount - 1 {
                Button(L10n.string("onboarding.next")) {
                    withAnimation(CarinhoMotion.gentle) {
                        page += 1
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(L10n.string("onboarding.finish")) {
                    skipVehicleSetup()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func defineVehicleAndFinish() {
        settings.completeOnboarding()
        CarinhoHaptics.selection()
        DispatchQueue.main.async {
            tabSelection.openPairing()
        }
    }

    private func skipVehicleSetup() {
        settings.completeOnboarding()
        settings.skipCarSetup()
        CarinhoHaptics.selection()
    }
}

#Preview {
    OnboardingView()
}
