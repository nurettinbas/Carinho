import SwiftUI

public enum TrailhoundBrandColors {
    public static let brandTop = Color(red: 0.42, green: 0.71, blue: 0.93)
    public static let brandBottom = Color(red: 0.23, green: 0.56, blue: 0.85)
    public static let recording = Color.red
    public static let paused = Color.orange
    public static let resume = Color.green
    public static let stop = Color.red
    public static let start = brandBottom

    public static let activeGradient = LinearGradient(
        colors: [brandTop, brandBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let pausedGradient = LinearGradient(
        colors: [
            Color(red: 0.36, green: 0.58, blue: 0.72),
            Color(red: 0.28, green: 0.44, blue: 0.58)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
