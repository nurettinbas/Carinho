import SwiftUI

enum PairingCardStyle {
    static let cardRadius: CGFloat = GlassTokens.cardRadius
    static let cardShadow = Color.black.opacity(0.06)

    static func cardBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.12) : .white
    }
}

struct PairingCardContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .glassCard(cornerRadius: PairingCardStyle.cardRadius, contentInset: 0)
    }
}
