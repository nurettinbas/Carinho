import CoreLocation
import MapKit
import SwiftUI

enum RecordingMorphID {
    static let statusChip = "recording.statusChip"
    static let car = "recording.car"
}

struct ActiveTripView: View {
    var morphNamespace: Namespace.ID?
    var morphID: UUID?
    /// Staggered premium entrance — each piece inserts in order.
    var playEntranceReveal: Bool = false
    var onEntranceFinished: (() -> Void)?
    var onStop: (() -> Void)?

    @Environment(TripRecordingService.self) private var recordingService
    @Environment(LocationService.self) private var locationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breadcrumbCamera: MapCameraPosition = .automatic
    @State private var showPanel = true
    @State private var showStatus = true
    @State private var showCar = true
    @State private var showMap = true
    @State private var showStatDuration = true
    @State private var showStatSpeed = true
    @State private var showStatDistance = true
    @State private var showActions = true
    @State private var didRunEntrance = false

    init(
        morphNamespace: Namespace.ID? = nil,
        morphID: UUID? = nil,
        playEntranceReveal: Bool = false,
        onEntranceFinished: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil
    ) {
        self.morphNamespace = morphNamespace
        self.morphID = morphID
        self.playEntranceReveal = playEntranceReveal
        self.onEntranceFinished = onEntranceFinished
        self.onStop = onStop
        let visible = !playEntranceReveal
        _showPanel = State(initialValue: visible)
        _showStatus = State(initialValue: visible)
        _showCar = State(initialValue: visible)
        _showMap = State(initialValue: visible)
        _showStatDuration = State(initialValue: visible)
        _showStatSpeed = State(initialValue: visible)
        _showStatDistance = State(initialValue: visible)
        _showActions = State(initialValue: visible)
    }

    private var isPaused: Bool {
        recordingService.state == .paused
    }

    private var speedText: String {
        let kmh = Int(max(0, recordingService.currentSpeedMps) * 3.6)
        return "\(kmh) \(L10n.speedKmh)"
    }

    private var elapsedText: String {
        DateFormatters.formatDuration(recordingService.elapsedTime)
    }

    private var distanceText: String {
        DateFormatters.formatDistance(recordingService.currentDistanceMeters)
    }

    private var statusText: String {
        isPaused ? L10n.recordingPaused : L10n.recordingStarted
    }

    private var breadcrumbCoordinates: [CLLocationCoordinate2D] {
        recordingService.liveBreadcrumbCoordinates
    }

    private var liveDotCoordinate: CLLocationCoordinate2D? {
        locationService.lastLocation?.coordinate ?? breadcrumbCoordinates.last
    }

    var body: some View {
        if recordingService.state.isActiveSession {
            recordingCard
        } else {
            EmptyView()
        }
    }

    private var recordingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showStatus {
                statusRow
                    .transition(TrailhoundMotion.softRiseTransition)
            }

            if showPanel {
                HStack(alignment: .center, spacing: 10) {
                    RecordingCarAnimationView(compact: true, isAnimating: !isPaused && showCar)
                        .frame(maxWidth: .infinity)
                        .matchedGeometryEffectIfAvailable(
                            stringID: RecordingMorphID.car,
                            namespace: morphNamespace,
                            isSource: true
                        )
                        .opacity(showCar ? 1 : 0)
                        .offset(x: showCar ? 0 : -28)
                        .accessibilityHidden(!showCar)

                    liveBreadcrumbMap
                        .frame(width: 96, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
                        }
                        .matchedGeometryEffectIfAvailable(
                            id: morphID,
                            namespace: morphNamespace,
                            isSource: true
                        )
                        // Keep MapKit warm at whisper opacity while hidden.
                        .opacity(showMap ? 1 : 0.02)
                        .scaleEffect(showMap ? 1 : 0.92)
                        .accessibilityHidden(!showMap)
                }
                .frame(height: 72)
            }

            if showStatDuration || showStatSpeed || showStatDistance {
                HStack(alignment: .top, spacing: 8) {
                    if showStatDuration {
                        statPill(icon: "clock.fill", label: L10n.duration, text: elapsedText)
                            .transition(TrailhoundMotion.softRiseTransition)
                    }
                    if showStatSpeed {
                        statPill(icon: "speedometer", label: L10n.currentSpeed, text: speedText)
                            .transition(TrailhoundMotion.softRiseTransition)
                    }
                    if showStatDistance {
                        statPill(
                            icon: "location.fill",
                            label: L10n.string("label.distance"),
                            text: distanceText
                        )
                        .transition(TrailhoundMotion.softRiseTransition)
                    }
                }
            }

            if showActions {
                actionsRow
                    .transition(TrailhoundMotion.softRiseFromBottomTransition)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if showPanel {
                RecordingCardStyle.background(isPaused: isPaused)
                    .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .task(id: morphID) {
            await runEntranceIfNeeded()
        }
        .onChange(of: playEntranceReveal) { wasPlaying, shouldPlay in
            guard shouldPlay, !wasPlaying else { return }
            prepareEntranceReplay()
            Task { await runEntranceIfNeeded() }
        }
        .onAppear { syncBreadcrumbCamera(animated: false) }
        .onChange(of: breadcrumbCoordinates.count) { _, _ in
            syncBreadcrumbCamera(animated: !reduceMotion)
        }
        .onChange(of: locationService.lastLocation?.coordinate.latitude) { _, _ in
            syncBreadcrumbCamera(animated: !reduceMotion)
        }
    }

    private var statusRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .font(.subheadline)
                    .foregroundStyle(statusColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: !isPaused && !reduceMotion)
                Text(statusText)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .matchedGeometryEffectIfAvailable(
                stringID: RecordingMorphID.statusChip,
                namespace: morphNamespace,
                isSource: true
            )

            Spacer(minLength: 4)

            GPSQualityBadge(quality: locationService.gpsQuality)
        }
    }

    private var actionsRow: some View {
        HStack(spacing: 8) {
            Button {
                if isPaused {
                    recordingService.resumeRecording()
                } else {
                    recordingService.pauseRecording()
                }
            } label: {
                Label(isPaused ? L10n.resume : L10n.pause, systemImage: isPaused ? "play.fill" : "pause.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftPressBorderedButtonStyle(reduceMotion: reduceMotion))
            .controlSize(.small)
            .tint(.white)

            Button(role: .destructive) {
                if let onStop {
                    onStop()
                } else {
                    recordingService.stopManualRecording()
                }
            } label: {
                Text(L10n.stop)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.red)
        }
    }

    @MainActor
    private func prepareEntranceReplay() {
        didRunEntrance = false
        guard !reduceMotion else { return }
        showPanel = false
        showStatus = false
        showCar = false
        showMap = false
        showStatDuration = false
        showStatSpeed = false
        showStatDistance = false
        showActions = false
    }

    @MainActor
    private func runEntranceIfNeeded() async {
        guard playEntranceReveal else {
            // Appearing mid-session (e.g. tab return) — show everything.
            if !didRunEntrance {
                revealAll()
                didRunEntrance = true
            }
            return
        }
        guard !didRunEntrance else { return }
        didRunEntrance = true

        if reduceMotion {
            revealAll()
            onEntranceFinished?()
            return
        }

        // 1) Shell + status (soft rise) — map row mounts hidden to warm MapKit.
        withAnimation(TrailhoundMotion.coldOpenPiece) {
            showPanel = true
            showStatus = true
        }
        try? await Task.sleep(for: .milliseconds(220))
        if await entranceCancelled() { return }

        // 2) Car — soft slide from leading + fade
        withAnimation(TrailhoundMotion.coldOpenCar) {
            showCar = true
        }
        try? await Task.sleep(for: TrailhoundMotion.coldOpenPieceGap)
        if await entranceCancelled() { return }

        // 3) Map — scale 0.92 → 1 (no pop)
        withAnimation(TrailhoundMotion.coldOpenMap) {
            showMap = true
        }
        try? await Task.sleep(for: TrailhoundMotion.coldOpenPieceGap)
        if await entranceCancelled() { return }

        // 4) Pills — soft rise, left → right cascade (~75ms apart)
        withAnimation(TrailhoundMotion.coldOpenPill) {
            showStatDuration = true
        }
        try? await Task.sleep(for: TrailhoundMotion.coldOpenPillStagger)
        if await entranceCancelled() { return }

        withAnimation(TrailhoundMotion.coldOpenPill) {
            showStatSpeed = true
        }
        try? await Task.sleep(for: TrailhoundMotion.coldOpenPillStagger)
        if await entranceCancelled() { return }

        withAnimation(TrailhoundMotion.coldOpenPill) {
            showStatDistance = true
        }
        try? await Task.sleep(for: TrailhoundMotion.coldOpenPieceGap)
        if await entranceCancelled() { return }

        // 5) Buttons — rise from bottom together, single beat
        withAnimation(TrailhoundMotion.coldOpenActions) {
            showActions = true
        }
        try? await Task.sleep(for: .milliseconds(420))
        if await entranceCancelled() { return }

        onEntranceFinished?()
    }

    @MainActor
    private func entranceCancelled() async -> Bool {
        guard Task.isCancelled else { return false }
        revealAll()
        onEntranceFinished?()
        return true
    }

    private func revealAll() {
        showPanel = true
        showStatus = true
        showCar = true
        showMap = true
        showStatDuration = true
        showStatSpeed = true
        showStatDistance = true
        showActions = true
    }

    @ViewBuilder
    private var liveBreadcrumbMap: some View {
        Map(position: $breadcrumbCamera, interactionModes: []) {
            if breadcrumbCoordinates.count >= 2 {
                MapPolyline(coordinates: breadcrumbCoordinates)
                    .stroke(
                        Color.white.opacity(0.85),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
            }

            if let liveDotCoordinate {
                Annotation("", coordinate: liveDotCoordinate) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.28))
                            .frame(width: 16, height: 16)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 7, height: 7)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    }
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .disabled(true)
        .accessibilityHidden(true)
    }

    private func syncBreadcrumbCamera(animated: Bool) {
        let path = breadcrumbCoordinates
        let center = liveDotCoordinate ?? path.last
        guard let center else { return }

        var minLat = center.latitude
        var maxLat = center.latitude
        var minLon = center.longitude
        var maxLon = center.longitude
        for coordinate in path.suffix(40) {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(0.004, (maxLat - minLat) * 1.8),
                longitudeDelta: max(0.004, (maxLon - minLon) * 1.8)
            )
        )

        if animated {
            withAnimation(TrailhoundMotion.gentle) {
                breadcrumbCamera = .region(region)
            }
        } else {
            breadcrumbCamera = .region(region)
        }
    }

    private var statusIcon: String {
        isPaused ? "pause.circle.fill" : "record.circle.fill"
    }

    private var statusColor: Color {
        isPaused ? .yellow : .red
    }

    private var accessibilitySummary: String {
        let format = L10n.string("recording.accessibility.summary")
        return String(format: format, statusText, elapsedText, speedText, distanceText)
    }

    private func statPill(icon: String, label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(label, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.75))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(text)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .numericTextAnimation(value: text)
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(text)")
    }
}

#Preview {
    ActiveTripView(playEntranceReveal: true)
        .environment(PreviewData.shared.recordingService)
        .environment(LocationService())
}
