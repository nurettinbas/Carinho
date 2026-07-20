import AppIntents
import SwiftUI

struct PairingShortcutsAutomationCard: View {
    let onOpenGuide: () -> Void

    var body: some View {
        PairingCardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(TrailhoundBrandColors.brandBottom.opacity(0.12))
                            .frame(width: 40, height: 40)
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.title3)
                            .foregroundStyle(TrailhoundBrandColors.brandBottom)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.pairingShortcutsGuideCardTitle)
                            .font(.subheadline.weight(.semibold))
                        Text(L10n.pairingShortcutsGuideCardSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button(action: onOpenGuide) {
                    Text(L10n.pairingShortcutsGuideCardButton)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(TrailhoundBrandColors.brandBottom)
            }
            .padding(12)
        }
    }
}

struct PairingShortcutsAutomationGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var settings = AppSettings.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n.pairingShortcutsGuideIntro)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    prerequisiteSection
                    automationSection(
                        title: L10n.pairingShortcutsGuideConnectTitle,
                        steps: connectSteps,
                        symbol: "play.circle.fill",
                        tint: .green
                    )
                    automationSection(
                        title: L10n.pairingShortcutsGuideDisconnectTitle,
                        steps: disconnectSteps,
                        symbol: "stop.circle.fill",
                        tint: .red
                    )

                    Text(L10n.pairingShortcutsGuideNote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ShortcutsLink()
                        .shortcutsLinkStyle(.automaticOutline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel(L10n.pairingShortcutsGuideOpenShortcuts)
                }
                .padding()
            }
            .navigationTitle(L10n.pairingShortcutsGuideTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.pairingShortcutsGuideDone) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var prerequisiteSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(L10n.pairingShortcutsGuidePrerequisiteTitle, systemImage: "checkmark.shield")
                .font(.headline)

            Text(L10n.pairingShortcutsGuidePrerequisiteBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(L10n.pairingShortcutsGuideSilentStart, isOn: $settings.confirmExternalRecordingStart.inverted)
                .font(.subheadline)
                .tint(TrailhoundBrandColors.brandBottom)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var connectSteps: [String] {
        [
            L10n.pairingShortcutsGuideConnectStep1,
            L10n.pairingShortcutsGuideConnectStep2,
            L10n.pairingShortcutsGuideConnectStep3,
            L10n.pairingShortcutsGuideConnectStep4,
            L10n.pairingShortcutsGuideConnectStep5
        ]
    }

    private var disconnectSteps: [String] {
        [
            L10n.pairingShortcutsGuideDisconnectStep1,
            L10n.pairingShortcutsGuideDisconnectStep2,
            L10n.pairingShortcutsGuideDisconnectStep3,
            L10n.pairingShortcutsGuideDisconnectStep4
        ]
    }

    private func automationSection(
        title: String,
        steps: [String],
        symbol: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(tint.opacity(0.85))
                            .clipShape(Circle())

                        Text(step)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private extension Binding where Value == Bool {
    var inverted: Binding<Bool> {
        Binding(
            get: { !wrappedValue },
            set: { wrappedValue = !$0 }
        )
    }
}

#Preview("Card") {
    PairingShortcutsAutomationCard(onOpenGuide: {})
        .padding()
}

#Preview("Guide") {
    PairingShortcutsAutomationGuideView()
}
