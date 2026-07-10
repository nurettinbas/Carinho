import SwiftUI

enum RecordingCardStyle {
    static let activeGradient = LinearGradient(
        colors: [
            Color(red: 0.42, green: 0.71, blue: 0.93),
            Color(red: 0.23, green: 0.56, blue: 0.85)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let pausedGradient = LinearGradient(
        colors: [
            Color(red: 0.36, green: 0.58, blue: 0.72),
            Color(red: 0.28, green: 0.44, blue: 0.58)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

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
