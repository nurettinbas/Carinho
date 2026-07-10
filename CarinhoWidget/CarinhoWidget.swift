import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

private enum WidgetL10n {
    private static func text(_ key: String) -> String {
        SharedL10n.text(key)
    }

    static var pause: String { text("action.pause") }
    static var resume: String { text("action.resume") }
    static var stop: String { text("action.stop") }
    static var start: String { text("action.start") }
    static var paused: String { text("live_activity.paused") }
    static var recording: String { text("live_activity.recording") }
    static var noRecording: String { text("widget.no_recording") }
    static var thisWeek: String { text("section.this_week") }
    static var liveRecording: String { text("widget.live_recording") }
    static var displayName: String { text("widget.display_name") }
    static var description: String { text("widget.description") }
}

private enum WidgetPalette {
    static let brandTop = CarinhoBrandColors.brandTop
    static let brandBottom = CarinhoBrandColors.brandBottom
    static let recording = CarinhoBrandColors.recording
    static let paused = CarinhoBrandColors.paused
    static let resume = CarinhoBrandColors.resume
    static let stop = CarinhoBrandColors.stop
    static let start = CarinhoBrandColors.start
}

private struct WidgetAdaptiveBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    var body: some View {
        if renderingMode == .fullColor {
            LinearGradient(
                colors: [WidgetPalette.brandTop.opacity(0.28), WidgetPalette.brandBottom.opacity(0.14)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct WidgetIntentButton<Intent: AppIntent>: View {
    enum Size {
        case regular
        case small
    }

    let title: String
    let systemImage: String
    let tint: Color
    let size: Size
    let iconOnly: Bool
    let intent: Intent

    @Environment(\.widgetRenderingMode) private var renderingMode

    private var usesLiquidGlassLayout: Bool {
        renderingMode != .fullColor
    }

    init(
        title: String,
        systemImage: String,
        tint: Color,
        size: Size,
        iconOnly: Bool = false,
        intent: Intent
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.size = size
        self.iconOnly = iconOnly
        self.intent = intent
    }

    var body: some View {
        Group {
            if usesLiquidGlassLayout {
                if iconOnly {
                    Button(intent: intent) {
                        label
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                } else {
                    Button(intent: intent) {
                        label
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(tint)
                }
            } else {
                Button(intent: intent) {
                    label
                        .frame(maxWidth: iconOnly ? nil : .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
            }
        }
        .controlSize(size == .small ? .small : .regular)
        .accessibilityLabel(title)
    }

    @ViewBuilder
    private var label: some View {
        if iconOnly {
            Image(systemName: systemImage)
                .font(iconOnlyFont.weight(.bold))
                .frame(width: iconOnlyDimension, height: iconOnlyDimension)
        } else {
            Label(title, systemImage: systemImage)
                .font(labelFont)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var labelFont: Font {
        switch size {
        case .regular: .caption.weight(.semibold)
        case .small: .caption2.weight(.semibold)
        }
    }

    private var iconOnlyFont: Font {
        switch size {
        case .regular: .body
        case .small: .caption
        }
    }

    private var iconOnlyDimension: CGFloat {
        switch size {
        case .regular: 28
        case .small: 24
        }
    }
}

struct CarinhoWidgetEntry: TimelineEntry {
    let date: Date
    let isRecording: Bool
    let isPaused: Bool
    let elapsed: TimeInterval
    let distanceMeters: Double
    let weekDistanceMeters: Double

    static func preview(
        isRecording: Bool = true,
        isPaused: Bool = false,
        elapsed: TimeInterval = 3_723,
        distanceMeters: Double = 12_400,
        weekDistanceMeters: Double = 45_200
    ) -> CarinhoWidgetEntry {
        CarinhoWidgetEntry(
            date: .now,
            isRecording: isRecording,
            isPaused: isPaused,
            elapsed: elapsed,
            distanceMeters: distanceMeters,
            weekDistanceMeters: weekDistanceMeters
        )
    }
}

struct CarinhoWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarinhoWidgetEntry {
        .preview(isRecording: true, isPaused: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (CarinhoWidgetEntry) -> Void) {
        if context.isPreview {
            completion(.preview(isRecording: true, isPaused: false))
        } else {
            completion(loadEntry())
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarinhoWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let refreshInterval: TimeInterval = entry.isRecording ? 15 : 30
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(refreshInterval)))
        completion(timeline)
    }

    private func loadEntry() -> CarinhoWidgetEntry {
        let defaults = UserDefaults(suiteName: "group.com.carinho.app")
        return CarinhoWidgetEntry(
            date: Date(),
            isRecording: defaults?.bool(forKey: "recording.isActive") ?? false,
            isPaused: defaults?.bool(forKey: "recording.isPaused") ?? false,
            elapsed: defaults?.double(forKey: "recording.elapsed") ?? 0,
            distanceMeters: defaults?.double(forKey: "recording.distance") ?? 0,
            weekDistanceMeters: defaults?.double(forKey: "stats.weekDistance") ?? 0
        )
    }
}

struct CarinhoWidgetView: View {
    let entry: CarinhoWidgetEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode

    private var usesLiquidGlassLayout: Bool {
        renderingMode != .fullColor
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        case .systemLarge:
            largeView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            widgetHeader(compact: true)

            if entry.isRecording || entry.isPaused {
                Text(entry.isPaused ? WidgetL10n.paused : WidgetL10n.recording)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(
                        usesLiquidGlassLayout
                            ? .primary
                            : (entry.isPaused ? WidgetPalette.paused : WidgetPalette.recording)
                    )
                    .lineLimit(1)
                Text(DateFormatters.formatDuration(entry.elapsed))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Text(DateFormatters.formatDistance(entry.distanceMeters))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                recordingControlsSmall
            } else {
                Text(WidgetL10n.thisWeek)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(DateFormatters.formatDistance(entry.weekDistanceMeters))
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                Spacer(minLength: 0)
                WidgetIntentButton(
                    title: WidgetL10n.start,
                    systemImage: "play.fill",
                    tint: WidgetPalette.start,
                    size: .small,
                    intent: WidgetStartRecordingIntent()
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetHeader(compact: false)

            if entry.isRecording || entry.isPaused {
                statusBadge
                Text("\(DateFormatters.formatDuration(entry.elapsed)) · \(DateFormatters.formatDistance(entry.distanceMeters))")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else {
                Text(WidgetL10n.thisWeek)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(DateFormatters.formatDistance(entry.weekDistanceMeters))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }

            Spacer(minLength: 0)
            recordingControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            widgetHeader(compact: false)

            if entry.isRecording || entry.isPaused {
                statusBadge
                Text(DateFormatters.formatDuration(entry.elapsed))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(DateFormatters.formatDistance(entry.distanceMeters))
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                Text(WidgetL10n.thisWeek)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(DateFormatters.formatDistance(entry.weekDistanceMeters))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(WidgetL10n.noRecording)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
            recordingControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func widgetHeader(compact: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "car.fill")
                .font(compact ? .subheadline : .headline)
                .foregroundStyle(usesLiquidGlassLayout ? .primary : WidgetPalette.brandBottom)
                .widgetAccentable(usesLiquidGlassLayout)
            Text("Carinho")
                .font(compact ? .subheadline.weight(.semibold) : .headline)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let title = entry.isPaused ? WidgetL10n.paused : WidgetL10n.recording
        if usesLiquidGlassLayout {
            Text(title)
                .font(.caption.weight(.semibold))
        } else {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(entry.isPaused ? WidgetPalette.paused : WidgetPalette.recording)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (entry.isPaused ? WidgetPalette.paused : WidgetPalette.recording).opacity(0.14),
                    in: Capsule()
                )
        }
    }

    @ViewBuilder
    private var recordingControls: some View {
        if entry.isRecording || entry.isPaused {
            HStack(spacing: 8) {
                if entry.isPaused {
                    WidgetIntentButton(
                        title: WidgetL10n.resume,
                        systemImage: "play.fill",
                        tint: WidgetPalette.resume,
                        size: .regular,
                        intent: WidgetResumeRecordingIntent()
                    )
                } else {
                    WidgetIntentButton(
                        title: WidgetL10n.pause,
                        systemImage: "pause.fill",
                        tint: WidgetPalette.paused,
                        size: .regular,
                        intent: WidgetPauseRecordingIntent()
                    )
                }

                WidgetIntentButton(
                    title: WidgetL10n.stop,
                    systemImage: "stop.fill",
                    tint: WidgetPalette.stop,
                    size: .regular,
                    intent: WidgetStopRecordingIntent()
                )
            }
        } else {
            WidgetIntentButton(
                title: WidgetL10n.start,
                systemImage: "play.fill",
                tint: WidgetPalette.start,
                size: .regular,
                intent: WidgetStartRecordingIntent()
            )
        }
    }

    @ViewBuilder
    private var recordingControlsSmall: some View {
        HStack(spacing: 6) {
            if entry.isPaused {
                WidgetIntentButton(
                    title: WidgetL10n.resume,
                    systemImage: "play.fill",
                    tint: WidgetPalette.resume,
                    size: .small,
                    intent: WidgetResumeRecordingIntent()
                )
            } else {
                WidgetIntentButton(
                    title: WidgetL10n.pause,
                    systemImage: "pause.fill",
                    tint: WidgetPalette.paused,
                    size: .small,
                    intent: WidgetPauseRecordingIntent()
                )
            }

            WidgetIntentButton(
                title: WidgetL10n.stop,
                systemImage: "stop.fill",
                tint: WidgetPalette.stop,
                size: .small,
                intent: WidgetStopRecordingIntent()
            )
        }
    }
}

struct CarinhoWidget: Widget {
    let kind = "CarinhoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarinhoWidgetProvider()) { entry in
            CarinhoWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetAdaptiveBackground()
                }
        }
        .configurationDisplayName(WidgetL10n.displayName)
        .description(WidgetL10n.description)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct LiveActivityCarIcon: View {
    let isPaused: Bool
    var font: Font = .title2

    var body: some View {
        Group {
            if isPaused {
                Image(systemName: "pause.circle.fill")
                    .foregroundStyle(.orange)
            } else {
                Image(systemName: "car.side.fill")
                    .foregroundStyle(.blue)
                    .scaleEffect(x: -1, y: 1)
            }
        }
        .font(font)
    }
}

struct CarinhoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripRecordingAttributes.self) { context in
            HStack(spacing: 12) {
                LiveActivityCarIcon(isPaused: context.state.isPaused)

                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.isPaused ? WidgetL10n.paused : WidgetL10n.recording)
                        .font(.headline)
                        .foregroundStyle(context.state.isPaused ? .orange : .primary)
                    Text(liveActivityStats(context.state))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Spacer()

                liveActivityControls(isPaused: context.state.isPaused)
            }
            .padding()
            .activityBackgroundTint((context.state.isPaused ? Color.orange : Color.blue).opacity(0.12))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    LiveActivityCarIcon(isPaused: context.state.isPaused, font: .title3)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading) {
                        Text(context.state.isPaused ? WidgetL10n.paused : WidgetL10n.recording)
                            .font(.caption)
                            .foregroundStyle(context.state.isPaused ? .orange : .primary)
                        Text("\(DateFormatters.formatDuration(TimeInterval(context.state.elapsedSeconds))) · \(context.state.currentSpeedKmh) km/s")
                            .font(.headline)
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    liveActivityControls(isPaused: context.state.isPaused)
                }
            } compactLeading: {
                LiveActivityCarIcon(isPaused: context.state.isPaused, font: .caption)
            } compactTrailing: {
                Text(DateFormatters.formatDuration(TimeInterval(context.state.elapsedSeconds)))
                    .font(.caption2)
                    .monospacedDigit()
            } minimal: {
                LiveActivityCarIcon(isPaused: context.state.isPaused, font: .caption2)
            }
        }
    }

    @ViewBuilder
    private func liveActivityControls(isPaused: Bool) -> some View {
        HStack(spacing: 8) {
            if isPaused {
                WidgetIntentButton(
                    title: WidgetL10n.resume,
                    systemImage: "play.fill",
                    tint: WidgetPalette.resume,
                    size: .small,
                    iconOnly: true,
                    intent: WidgetResumeRecordingIntent()
                )
            } else {
                WidgetIntentButton(
                    title: WidgetL10n.pause,
                    systemImage: "pause.fill",
                    tint: WidgetPalette.paused,
                    size: .small,
                    iconOnly: true,
                    intent: WidgetPauseRecordingIntent()
                )
            }

            WidgetIntentButton(
                title: WidgetL10n.stop,
                systemImage: "stop.fill",
                tint: WidgetPalette.stop,
                size: .small,
                iconOnly: true,
                intent: WidgetStopRecordingIntent()
            )
        }
    }

    private func liveActivityStats(_ state: TripRecordingAttributes.ContentState) -> String {
        if state.isPaused {
            return "\(DateFormatters.formatDuration(TimeInterval(state.elapsedSeconds))) · \(DateFormatters.formatDistance(state.distanceMeters))"
        }
        return "\(DateFormatters.formatDuration(TimeInterval(state.elapsedSeconds))) · \(DateFormatters.formatDistance(state.distanceMeters)) · \(state.currentSpeedKmh) km/s"
    }
}

@main
struct CarinhoWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarinhoWidget()
        CarinhoLiveActivity()
    }
}

#Preview(as: .systemSmall) {
    CarinhoWidget()
} timeline: {
    CarinhoWidgetEntry.preview(isRecording: true, isPaused: false)
    CarinhoWidgetEntry.preview(isRecording: true, isPaused: true)
    CarinhoWidgetEntry.preview(isRecording: false, isPaused: false)
}

#Preview(as: .systemMedium) {
    CarinhoWidget()
} timeline: {
    CarinhoWidgetEntry.preview(isRecording: true, isPaused: false)
    CarinhoWidgetEntry.preview(isRecording: false, isPaused: false)
}

#Preview(as: .systemLarge) {
    CarinhoWidget()
} timeline: {
    CarinhoWidgetEntry.preview(isRecording: true, isPaused: false)
    CarinhoWidgetEntry.preview(isRecording: false, isPaused: false)
}
