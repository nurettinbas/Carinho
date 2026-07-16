import SwiftUI

enum RecordingCardStyle {
    static let activeGradient = TrailhoundBrandColors.activeGradient
    static let pausedGradient = TrailhoundBrandColors.pausedGradient

    static func background(isPaused: Bool) -> LinearGradient {
        isPaused ? pausedGradient : activeGradient
    }
}

#Preview {
    ZStack {
        RecordingCardStyle.background(isPaused: false)
        RecordingCarAnimationView()
            .padding(.horizontal)
    }
    .frame(height: 140)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding()
}
