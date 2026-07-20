import AppIntents
import SwiftUI
import UIKit

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

    private var brandAccent: Color { TrailhoundBrandColors.brandBottom }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(L10n.pairingShortcutsGuideIntro)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        prerequisiteSection
                        triggerOptionsSection
                        automationFlowSection(
                            title: L10n.pairingShortcutsGuideConnectTitle,
                            steps: connectSteps,
                            stepIcons: ["apps.iphone", "plus.circle.fill", "point.3.connected.trianglepath.dotted", "play.fill", "bell.slash.fill"],
                            symbol: "play.circle.fill",
                            triggerChipStepIndex: 2,
                            actionChipStepIndex: 3,
                            actionChipTitle: L10n.shortcutStartTitle
                        )
                        automationFlowSection(
                            title: L10n.pairingShortcutsGuideDisconnectTitle,
                            steps: disconnectSteps,
                            stepIcons: ["plus.circle.fill", "point.3.connected.trianglepath.dotted", "stop.fill", "bell.slash.fill"],
                            symbol: "stop.circle.fill",
                            triggerChipStepIndex: 1,
                            actionChipStepIndex: 2,
                            actionChipTitle: L10n.shortcutStopTitle
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
                    .frame(width: geometry.size.width, alignment: .leading)
                }
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
            guideSectionHeader(title: L10n.pairingShortcutsGuidePrerequisiteTitle, symbol: "checkmark.shield")

            Text(L10n.pairingShortcutsGuidePrerequisiteBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(L10n.pairingShortcutsGuideSilentStart, isOn: $settings.confirmExternalRecordingStart.inverted)
                .font(.subheadline)
                .tint(TrailhoundBrandColors.brandBottom)
        }
        .padding(14)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var triggerOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            guideSectionHeader(title: L10n.pairingShortcutsGuideTriggersTitle, symbol: "list.bullet.rectangle")

            Text(L10n.pairingShortcutsGuideTriggersIntro)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                triggerOptionRow(
                    symbol: "bluetooth",
                    title: L10n.pairingShortcutsGuideTriggersBluetoothTitle,
                    body: L10n.pairingShortcutsGuideTriggersBluetoothBody
                )
                Divider().padding(.leading, 52)
                triggerOptionRow(
                    symbol: "carplay",
                    title: L10n.pairingShortcutsGuideTriggersCarPlayTitle,
                    body: L10n.pairingShortcutsGuideTriggersCarPlayBody
                )
                Divider().padding(.leading, 52)
                triggerOptionRow(
                    symbol: "wifi",
                    title: L10n.pairingShortcutsGuideTriggersWiFiTitle,
                    body: L10n.pairingShortcutsGuideTriggersWiFiBody
                )
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func triggerOptionRow(
        symbol: String,
        title: String,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(brandAccent)
                    .frame(width: 36, height: 36)
                Image(systemName: resolvedTriggerSymbol(symbol))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
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

    private func guideSectionHeader(title: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(brandAccent)
            Text(title)
                .font(.headline)
        }
    }

    private func resolvedTriggerSymbol(_ symbol: String) -> String {
        switch symbol {
        case "bluetooth":
            return UIImage(systemName: "bluetooth") != nil
                ? "bluetooth"
                : "antenna.radiowaves.left.and.right"
        case "carplay":
            return UIImage(systemName: "carplay") != nil
                ? "carplay"
                : "play.circle.fill"
        default:
            return symbol
        }
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

    private func automationFlowSection(
        title: String,
        steps: [String],
        stepIcons: [String],
        symbol: String,
        triggerChipStepIndex: Int?,
        actionChipStepIndex: Int?,
        actionChipTitle: String
    ) -> some View {
        let tint = brandAccent

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.08))

            Divider().opacity(0.35)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    automationStepRow(
                        number: index + 1,
                        text: step,
                        icon: stepIcons.indices.contains(index) ? stepIcons[index] : "circle.fill",
                        tint: tint,
                        isLast: index == steps.count - 1,
                        showsTriggerChips: triggerChipStepIndex == index,
                        showsActionChip: actionChipStepIndex == index,
                        actionChipTitle: actionChipTitle
                    )
                }
            }
            .padding(14)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(tint.opacity(0.18), lineWidth: 1)
                }
        }
    }

    private func automationStepRow(
        number: Int,
        text: String,
        icon: String,
        tint: Color,
        isLast: Bool,
        showsTriggerChips: Bool,
        showsActionChip: Bool,
        actionChipTitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack(alignment: .top) {
                if !isLast {
                    Rectangle()
                        .fill(tint.opacity(0.22))
                        .frame(width: 2)
                        .padding(.top, 11)
                        .frame(maxHeight: .infinity, alignment: .top)
                }

                ZStack {
                    Circle()
                        .fill(tint)
                        .frame(width: 22, height: 22)
                    Text("\(number)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 22)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 14, alignment: .center)
                        .padding(.top, 1)

                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showsTriggerChips {
                    triggerChipsRow
                }

                if showsActionChip {
                    actionChip(title: actionChipTitle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, isLast ? 2 : 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var triggerChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                triggerChip(symbol: "bluetooth", label: L10n.pairingShortcutsGuideTriggersBluetoothTitle)
                triggerChip(symbol: "carplay", label: L10n.pairingShortcutsGuideTriggersCarPlayTitle)
                triggerChip(symbol: "wifi", label: L10n.pairingShortcutsGuideTriggersWiFiTitle)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .clipped()
    }

    private func triggerChip(symbol: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: resolvedTriggerSymbol(symbol))
                .font(.system(size: 9, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(brandAccent)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(brandAccent.opacity(0.12))
        .clipShape(Capsule())
    }

    private func actionChip(title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "app.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(brandAccent)
            Text("Trailhound")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(brandAccent)
            Image(systemName: "chevron.right")
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(brandAccent)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .strokeBorder(brandAccent.opacity(0.25), lineWidth: 1)
        }
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
