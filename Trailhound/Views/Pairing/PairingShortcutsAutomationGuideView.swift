import AppIntents
import SwiftUI

struct PairingShortcutsAutomationCard: View {
    let onOpenGuide: () -> Void

    var body: some View {
        PairingCardContainer {
            Button(action: onOpenGuide) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(TrailhoundBrandColors.brandBottom.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .font(.body)
                            .foregroundStyle(TrailhoundBrandColors.brandBottom)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.pairingShortcutsGuideCardTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(L10n.pairingShortcutsGuideCardSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    Text(L10n.pairingShortcutsGuideCardButton)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(TrailhoundBrandColors.brandBottom)
                        .lineLimit(1)

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
                    triggerOptionsSection
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

    private var triggerOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.pairingShortcutsGuideTriggersTitle, systemImage: "list.bullet.rectangle")
                .font(.headline)

            Text(L10n.pairingShortcutsGuideTriggersIntro)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                triggerOptionRow(
                    symbol: "bluetooth",
                    tint: .blue,
                    title: L10n.pairingShortcutsGuideTriggersBluetoothTitle,
                    body: L10n.pairingShortcutsGuideTriggersBluetoothBody
                )
                Divider().padding(.leading, 52)
                triggerOptionRow(
                    symbol: "carplay",
                    tint: .green,
                    title: L10n.pairingShortcutsGuideTriggersCarPlayTitle,
                    body: L10n.pairingShortcutsGuideTriggersCarPlayBody
                )
                Divider().padding(.leading, 52)
                triggerOptionRow(
                    symbol: "wifi",
                    tint: .blue,
                    title: L10n.pairingShortcutsGuideTriggersWiFiTitle,
                    body: L10n.pairingShortcutsGuideTriggersWiFiBody
                )
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func triggerOptionRow(
        symbol: String,
        tint: Color,
        title: String,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
