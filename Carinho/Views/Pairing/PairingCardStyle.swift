import SwiftUI

enum PairingCardStyle {
    static let cardRadius: CGFloat = 14
    static let cardShadow = Color.black.opacity(0.04)

    static func cardBackground(_ colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(white: 0.12) : .white
    }
}

struct PairingCardContainer<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .background(PairingCardStyle.cardBackground(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: PairingCardStyle.cardRadius, style: .continuous))
            .shadow(color: PairingCardStyle.cardShadow, radius: 6, y: 2)
    }
}
