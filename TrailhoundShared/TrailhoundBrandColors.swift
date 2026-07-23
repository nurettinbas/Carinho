import SwiftUI

public enum TrailhoundBrandColors {
    public static let brandTop = Color(red: 0.42, green: 0.71, blue: 0.93)
    public static let brandBottom = Color(red: 0.23, green: 0.56, blue: 0.85)
    public static let recording = Color.red
    public static let paused = Color.orange
    public static let resume = Color.green
    public static let stop = Color.red
    public static let start = brandBottom

    /// Light-mode atmospheric shell (behind glass) — clearly blue, not near-white.
    public static let atmosphereTop = Color(red: 0.52, green: 0.78, blue: 0.96)
    public static let atmosphereMid = Color(red: 0.68, green: 0.86, blue: 0.98)
    public static let atmosphereBottom = Color(red: 0.38, green: 0.66, blue: 0.92)

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
