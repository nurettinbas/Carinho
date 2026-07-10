import SwiftUI

enum RecordingCardStyle {
    static let activeGradient = CarinhoBrandColors.activeGradient
    static let pausedGradient = CarinhoBrandColors.pausedGradient

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
