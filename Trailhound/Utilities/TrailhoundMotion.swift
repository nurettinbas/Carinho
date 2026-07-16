import SwiftUI
import UIKit

enum TrailhoundMotion {
    static let snappy = Animation.snappy(duration: 0.35)
    static let gentle = Animation.easeInOut(duration: 0.3)
    static let cardSpring = Animation.spring(response: 0.45, dampingFraction: 0.82)

    static func cardAppearTransition(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.98)),
            removal: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.96))
        )
    }

    static func fadeScaleTransition(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .identity }
        return .opacity.combined(with: .scale(scale: 0.98))
    }
}

@MainActor
enum TrailhoundHaptics {
    static func recordingStarted() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func recordingPaused() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func recordingResumed() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func recordingStopped() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func pairingSucceeded() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func destructive() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
    }
}

private struct NumericTextAnimationModifier<V: Equatable>: ViewModifier {
    let value: V
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : TrailhoundMotion.snappy, value: value)
    }
}

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { geometry in
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0),
                                Color.white.opacity(0.35),
                                Color.white.opacity(0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: -geometry.size.width + phase * geometry.size.width * 2)
                        .onAppear {
                            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                                phase = 1
                            }
                        }
                    }
                    .mask(content)
                }
            }
    }
}

extension View {
    func numericTextAnimation<V: Equatable>(value: V) -> some View {
        modifier(NumericTextAnimationModifier(value: value))
    }

    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }

    func trailhoundCardTransition(reduceMotion: Bool) -> some View {
        transition(TrailhoundMotion.cardAppearTransition(reduceMotion: reduceMotion))
    }
}
