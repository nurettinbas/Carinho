import SwiftUI

struct RecordingCarAnimationView: View {
    var compact: Bool = false
    var isAnimating: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sceneHeight: CGFloat { compact ? 44 : 80 }
    private var shouldAnimate: Bool { isAnimating && !reduceMotion }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            RoadSceneDriver(
                liveTime: timeline.date.timeIntervalSinceReferenceDate,
                shouldAnimate: shouldAnimate,
                isPaused: !isAnimating,
                compact: compact,
                sceneHeight: sceneHeight
            )
        }
        .frame(height: sceneHeight)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 10))
        .accessibilityHidden(true)
    }
}

private struct RoadSceneDriver: View {
    let liveTime: TimeInterval
    let shouldAnimate: Bool
    let isPaused: Bool
    let compact: Bool
    let sceneHeight: CGFloat

    @State private var frozenRoadTime: TimeInterval = 0

    private var sceneTime: TimeInterval {
        shouldAnimate ? liveTime : frozenRoadTime
    }

    var body: some View {
        RoadDrivingScene(time: sceneTime, compact: compact, isPaused: isPaused)
            .frame(height: sceneHeight)
            .onAppear {
                frozenRoadTime = liveTime
            }
            .onChange(of: shouldAnimate) { _, animating in
                if animating {
                    frozenRoadTime = liveTime
                } else {
                    frozenRoadTime = liveTime
                }
            }
            .onChange(of: liveTime) { _, newTime in
                if shouldAnimate {
                    frozenRoadTime = newTime
                }
            }
    }
}

private struct RoadDrivingScene: View {
    let time: TimeInterval
    var compact: Bool = false
    var isPaused: Bool = false

    private var roadHeight: CGFloat { compact ? 18 : 30 }
    private var carSize: CGFloat { compact ? 22 : 36 }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let carCenterX = width * 0.58
            let roadTop = geo.size.height - roadHeight
            let carY = roadTop - carSize * 0.35

            ZStack(alignment: .bottom) {
                roadSurface(width: width)
                laneMarkings(width: width)
                exhaustSmoke(
                    originX: carCenterX - carSize * 0.48,
                    originY: carY + carSize * 0.08
                )
                carIcon(centerX: carCenterX, centerY: carY)

                if isPaused {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: compact ? 18 : 24, weight: .semibold))
                        .foregroundStyle(.yellow.opacity(0.95))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .position(x: carCenterX, y: carY)
                }
            }
        }
    }

    private func roadSurface(width: CGFloat) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(isPaused ? 0.16 : 0.22),
                        Color.black.opacity(isPaused ? 0.28 : 0.35)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(height: roadHeight)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.white.opacity(isPaused ? 0.2 : 0.35))
                    .frame(height: 2)
            }
    }

    private func laneMarkings(width: CGFloat) -> some View {
        let dashWidth: CGFloat = 22
        let dashSpacing: CGFloat = 18
        let patternLength = dashWidth + dashSpacing
        let scrollSpeed: CGFloat = 90
        let offset = -CGFloat(time.truncatingRemainder(dividingBy: Double(patternLength / scrollSpeed))) * scrollSpeed
        let dashCount = Int(width / patternLength) + 4

        return ZStack(alignment: .leading) {
            ForEach(0..<dashCount, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(isPaused ? 0.45 : 0.85))
                    .frame(width: dashWidth, height: 3)
                    .offset(x: offset + CGFloat(index) * patternLength)
            }
        }
        .frame(height: roadHeight, alignment: .center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .offset(y: -roadHeight * 0.38)
        .mask(
            Rectangle()
                .frame(height: roadHeight)
                .frame(maxHeight: .infinity, alignment: .bottom)
        )
    }

    private func carIcon(centerX: CGFloat, centerY: CGFloat) -> some View {
        let bounce = isPaused ? 0 : sin(time * 8) * 1.2

        return Image(systemName: "car.side.fill")
            .font(.system(size: carSize, weight: .semibold))
            .foregroundStyle(.white.opacity(isPaused ? 0.75 : 1))
            .scaleEffect(x: -1, y: 1)
            .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
            .position(x: centerX, y: centerY + bounce)
    }

    private func exhaustSmoke(originX: CGFloat, originY: CGFloat) -> some View {
        Group {
            if !isPaused {
                ZStack {
                    ForEach(0..<7, id: \.self) { index in
                        smokePuff(
                            originX: originX,
                            originY: originY,
                            index: index,
                            cycle: 1.1,
                            stagger: 0.16
                        )
                    }
                }
            }
        }
    }

    private func smokePuff(
        originX: CGFloat,
        originY: CGFloat,
        index: Int,
        cycle: Double,
        stagger: Double
    ) -> some View {
        let progress = (time + stagger * Double(index)).truncatingRemainder(dividingBy: cycle) / cycle
        let drift = CGFloat(progress)
        let size = 6 + drift * 14
        let x = originX - drift * 36 - CGFloat(index % 2) * 4
        let y = originY - drift * 22 + sin(progress * .pi) * 6
        let opacity = Double(1 - progress) * 0.55

        return Circle()
            .fill(Color.white.opacity(opacity))
            .frame(width: size, height: size)
            .blur(radius: 1.5 + drift * 2)
            .position(x: x, y: y)
    }
}

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
