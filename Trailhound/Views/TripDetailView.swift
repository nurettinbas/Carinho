import Charts
import CoreLocation
import MapKit
import SwiftData
import SwiftUI
import UIKit

private enum TripMapStyle {
    case standard
    case dark

    var mapStyle: MapStyle {
        switch self {
        case .standard:
            return .standard(elevation: .realistic)
        case .dark:
            return .standard(elevation: .realistic, emphasis: .muted)
        }
    }
}

private struct RevealedRouteSegment: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(NetworkMonitor.self) private var networkMonitor
    @Query private var places: [SavedPlace]
    @Query(sort: \UserCategory.sortOrder) private var categories: [UserCategory]
    @Bindable private var settings = AppSettings.shared

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var noteText: String = ""
    @State private var selectedLabel: String = ""
    @State private var selectedCategoryID: String = BuiltInCategory.personalID.uuidString
    @State private var startAddressText: String = ""
    @State private var endAddressText: String = ""
    @State private var startPlaceNameText: String = ""
    @State private var endPlaceNameText: String = ""
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false
    @State private var isRenderingShareCard = false
    @FocusState private var noteFocused: Bool
    @State private var originalNoteText: String = ""
    @State private var showFullscreenMap = false
    @State private var mapStyle: TripMapStyle = .standard
    @State private var editedStartedAt: Date = Date()
    @State private var editedEndedAt: Date = Date()
    @State private var trimHeadCount: Int = 0
    @State private var trimTailCount: Int = 0
    @State private var routeRevealProgress: Double = 0
    @State private var didStartRouteReveal = false
    @State private var routeRevealTask: Task<Void, Never>?
    @State private var mapClarity: Double = 0
    @State private var startPinVisible = false
    @State private var endPinVisible = false
    @State private var panelRisen = false
    @State private var statCountProgress: [String: Double] = [:]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sortedStops: [TripStop] {
        trip.stops.sorted { $0.startedAt < $1.startedAt }
    }

    private var viewModel: TripDetailViewModel {
        TripDetailViewModel(trip: trip, places: places, privacyRadius: settings.privacyRadiusMeters)
    }

    var body: some View {
        GeometryReader { geometry in
            let panelHeight = geometry.size.height * 0.52
            ZStack(alignment: .bottom) {
                ZStack(alignment: .topTrailing) {
                    tripMapView(style: mapStyle, interactive: panelRisen)
                        .overlay {
                            // Dark / soft-blur veil that clears as the dive begins.
                            ZStack {
                                Color.black.opacity(0.55 * (1 - mapClarity))
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.85 * (1 - mapClarity))
                            }
                            .allowsHitTesting(false)
                        }
                        .onTapGesture {
                            dismissNoteKeyboard()
                        }

                    VStack(alignment: .trailing, spacing: 8) {
                        if !networkMonitor.isConnected {
                            Text(L10n.tripMapOfflineHint)
                                .font(.caption2)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                        }

                        compactSpeedLegend
                            .opacity(mapClarity)

                        Button {
                            showFullscreenMap = true
                        } label: {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 34, height: 34)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .accessibilityLabel(L10n.mapFullscreen)
                        .opacity(mapClarity)
                    }
                    .padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, panelRisen ? panelHeight - 12 : 0)
                .animation(reduceMotion ? nil : TrailhoundMotion.sheetRise, value: panelRisen)

                detailPanel
                    .frame(height: panelHeight)
                    .offset(y: panelRisen ? 0 : panelHeight + 24)
                    .opacity(panelRisen ? 1 : 0)
                    .animation(reduceMotion ? nil : TrailhoundMotion.sheetRise, value: panelRisen)
                    .allowsHitTesting(panelRisen)
            }
        }
        .dismissKeyboardOnTap(focus: $noteFocused)
        .navigationTitle(L10n.tripDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await renderShareCard() }
                } label: {
                    if isRenderingShareCard {
                        ProgressView()
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isRenderingShareCard)
                .accessibilityLabel(L10n.share)
            }
        }
        .sheet(isPresented: $showFullscreenMap) {
            fullscreenMapSheet
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { shareImage = nil }) {
            if let shareImage {
                ActivityShareSheet(items: [shareImage])
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            noteText = trip.note ?? ""
            originalNoteText = noteText
            selectedLabel = trip.label ?? ""
            selectedCategoryID = trip.categoryID
            startAddressText = trip.startAddress ?? ""
            endAddressText = trip.endAddress ?? ""
            startPlaceNameText = trip.startPlaceName ?? ""
            endPlaceNameText = trip.endPlaceName ?? ""
            editedStartedAt = trip.startedAt
            editedEndedAt = trip.endedAt ?? Date()
            if reduceMotion {
                finishRouteRevealInstant()
            } else {
                startCinematicRevealIfNeeded()
            }
        }
        .onDisappear {
            routeRevealTask?.cancel()
            routeRevealTask = nil
        }
    }

    private func startCinematicRevealIfNeeded() {
        guard !didStartRouteReveal else { return }
        didStartRouteReveal = true

        let pathCount = max(viewModel.routeCoordinates.count, viewModel.coordinates.count)
        guard pathCount >= 2 else {
            finishRouteRevealInstant()
            return
        }

        routeRevealProgress = 0
        startPinVisible = false
        endPinVisible = false
        panelRisen = false
        mapClarity = 0
        statCountProgress = Dictionary(
            uniqueKeysWithValues: viewModel.summaryMetrics.map { ($0.id, 0.0) }
        )

        if let opening = viewModel.cinematicOpeningCamera() {
            cameraPosition = .camera(opening)
        } else if let region = viewModel.mapRegion(fit: .cinematicReveal) {
            cameraPosition = .region(region)
        }

        routeRevealTask?.cancel()
        routeRevealTask = Task { @MainActor in
            // Let the map mount under the dark veil.
            try? await Task.sleep(for: .milliseconds(160))
            guard !Task.isCancelled else { return }

            // 1) Dark → clear + camera begins the dive toward the start.
            withAnimation(TrailhoundMotion.mapClear) {
                mapClarity = 1
            }
            if let diveStart = viewModel.cinematicFollowCamera(routeProgress: 0) {
                withAnimation(.easeInOut(duration: 0.85)) {
                    cameraPosition = .camera(diveStart)
                }
            }

            try? await Task.sleep(for: .milliseconds(720))
            guard !Task.isCancelled else { return }

            // 2) Start pin pops, then the neon route draws on.
            withAnimation(TrailhoundMotion.pinPop) {
                startPinVisible = true
            }
            TrailhoundHaptics.selection()

            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }

            let duration: TimeInterval = pathCount < 50
                ? 2.0
                : min(3.1, 1.55 + Double(pathCount) * 0.012)
            let steps = 64
            let stepSleep = duration / Double(steps)

            for step in 1...steps {
                try? await Task.sleep(for: .seconds(stepSleep))
                guard !Task.isCancelled else { return }

                // Ease-in-out so the stroke accelerates mid-route then softens into the end.
                let linear = Double(step) / Double(steps)
                let progress = Self.smoothstep(linear)
                routeRevealProgress = progress

                if let follow = viewModel.cinematicFollowCamera(routeProgress: progress) {
                    cameraPosition = .camera(follow)
                }
            }

            guard !Task.isCancelled else { return }

            // 3) End pin settles, camera eases to the full route frame.
            withAnimation(TrailhoundMotion.pinPop) {
                endPinVisible = true
            }
            TrailhoundHaptics.selection()

            if let region = viewModel.mapRegion(fit: .detailWithPanel) {
                withAnimation(.easeInOut(duration: 0.95)) {
                    cameraPosition = .region(region)
                }
            }

            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }

            // 4) Bottom panel rises; stats count up in sequence.
            panelRisen = true
            await runStatCountUp()
        }
    }

    private func runStatCountUp() async {
        let metrics = viewModel.summaryMetrics
        for (index, metric) in metrics.enumerated() {
            if index > 0 {
                try? await Task.sleep(for: .milliseconds(140))
            }
            guard !Task.isCancelled else { return }

            let ticks = 22
            for tick in 1...ticks {
                try? await Task.sleep(for: .milliseconds(28))
                guard !Task.isCancelled else { return }
                let linear = Double(tick) / Double(ticks)
                statCountProgress[metric.id] = Self.smoothstep(linear)
            }
            statCountProgress[metric.id] = 1
        }
    }

    private static func smoothstep(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }

    private func finishRouteRevealInstant() {
        didStartRouteReveal = true
        routeRevealTask?.cancel()
        routeRevealTask = nil
        routeRevealProgress = 1
        mapClarity = 1
        startPinVisible = true
        endPinVisible = true
        panelRisen = true
        statCountProgress = Dictionary(
            uniqueKeysWithValues: viewModel.summaryMetrics.map { ($0.id, 1.0) }
        )
        if let region = viewModel.mapRegion(fit: .detailWithPanel) {
            cameraPosition = .region(region)
        }
    }

    private var detailPanel: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.28))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    tripHeader

                    statsStrip

                    if !viewModel.speedSamples.isEmpty {
                        speedChartCard
                    }

                    if !sortedStops.isEmpty {
                        detailSection(title: L10n.tripStopsSection) {
                            ForEach(Array(sortedStops.enumerated()), id: \.element.persistentModelID) { index, stop in
                                TripStopEditRow(stop: stop)
                                if index < sortedStops.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }

                    detailSection(title: L10n.tripEditTimesSection) {
                        DatePicker(L10n.tripStartedAt, selection: $editedStartedAt)
                            .font(.subheadline)

                        if trip.endedAt != nil {
                            DatePicker(L10n.tripEndedAt, selection: $editedEndedAt)
                                .font(.subheadline)
                        }
                    }

                    detailSection(title: L10n.tripTrimPointsSection) {
                        Stepper(L10n.tripTrimHead, value: $trimHeadCount, in: 0...maxTrimHead)
                        Stepper(L10n.tripTrimTail, value: $trimTailCount, in: 0...maxTrimTail)
                    }

                    detailSection(title: L10n.tripLocationOverrides) {
                        compactTextField(L10n.tripStartPlaceName, text: $startPlaceNameText)
                        compactTextField(L10n.tripEndPlaceName, text: $endPlaceNameText)
                        compactTextField(L10n.tripStartAddress, text: $startAddressText)
                        compactTextField(L10n.tripEndAddress, text: $endAddressText)
                    }

                    detailSection(title: "Kategori ve etiket") {
                        Picker("Kategori", selection: $selectedCategoryID) {
                            ForEach(categories) { category in
                                Label(category.name, systemImage: category.systemImage)
                                    .tag(category.id.uuidString)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedCategoryID) { _, _ in
                            dismissNoteKeyboard()
                        }

                        Picker("Etiket", selection: $selectedLabel) {
                            Text("Yok").tag("")
                            ForEach(TripLabelOption.allCases, id: \.rawValue) { option in
                                Text(option.rawValue).tag(option.rawValue)
                            }
                        }
                        .onChange(of: selectedLabel) { _, _ in
                            dismissNoteKeyboard()
                        }
                    }

                    detailSection(title: "Not") {
                        TextField("Not ekle…", text: $noteText, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($noteFocused)
                            .submitLabel(.done)
                            .onSubmit { dismissNoteKeyboard() }
                    }

                    Button("Değişiklikleri kaydet") {
                        saveEdits()
                        dismissNoteKeyboard()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TrailhoundBrandColors.brandBottom)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .dismissKeyboardOnScroll()
        }
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 16, y: -4)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var tripHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.routeSummary)
                .font(.headline)
                .lineLimit(2)

            Text(viewModel.dateText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.summaryMetrics) { metric in
                    let progress = statCountProgress[metric.id] ?? (panelRisen ? 1 : 0)
                    VStack(alignment: .leading, spacing: 2) {
                        Label(metric.title, systemImage: metric.icon)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .labelStyle(.titleAndIcon)
                        Text(metric.formatted(progress: progress))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .animation(reduceMotion ? nil : TrailhoundMotion.snappy, value: progress)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(progress > 0.01 || reduceMotion ? 1 : 0.35)
                    .scaleEffect(progress > 0.01 || reduceMotion ? 1 : 0.94)
                }
            }
        }
    }

    private var speedChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tripSpeedChart)
                .font(.subheadline.weight(.semibold))

            Chart(viewModel.speedSamples, id: \.id) { sample in
                AreaMark(
                    x: .value("Zaman", sample.date),
                    y: .value("Hız", sample.speedKmh)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [TrailhoundBrandColors.brandBottom.opacity(0.28), TrailhoundBrandColors.brandBottom.opacity(0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Zaman", sample.date),
                    y: .value("Hız", sample.speedKmh)
                )
                .foregroundStyle(TrailhoundBrandColors.brandBottom)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .chartYScale(domain: 0...viewModel.speedChartMaxKmh)
            .chartYAxisLabel(L10n.speedKmh)
            .frame(height: 120)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func detailSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func compactTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, text: text)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var compactSpeedLegend: some View {
        HStack(spacing: 8) {
            legendChip(color: .green, text: L10n.speedLegendSlow)
            legendChip(color: .yellow, text: L10n.speedLegendMedium)
            legendChip(color: .red, text: L10n.speedLegendFast)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func legendChip(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2)
        }
    }

    private var maxTrimHead: Int {
        max(0, trip.sortedPoints.count - trimTailCount - 2)
    }

    private var maxTrimTail: Int {
        max(0, trip.sortedPoints.count - trimHeadCount - 2)
    }

    @ViewBuilder
    private func tripMapView(style: TripMapStyle, interactive: Bool) -> some View {
        let revealedSegments = viewModel.revealedSpeedColoredSegments(progress: routeRevealProgress)
        let revealedFallback = viewModel.revealedFallbackCoordinates(progress: routeRevealProgress)
        // MapKit often skips in-place coordinate updates; key overlays by length
        // so each reveal tick replaces the stroke visibly.
        let revealTick = Int((routeRevealProgress * 200).rounded())
        let revealedItems = revealedSegments.map { segment in
            RevealedRouteSegment(
                id: "\(segment.id)-\(segment.coordinates.count)-\(revealTick)",
                coordinates: segment.coordinates,
                color: segment.color
            )
        }

        Map(position: $cameraPosition, interactionModes: interactive ? .all : []) {
            // Soft neon under-glow, then the crisp speed-colored stroke on top.
            ForEach(revealedItems) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(
                        segment.color.opacity(0.38),
                        style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveRoads)
            }

            ForEach(revealedItems) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveRoads)
            }

            if revealedItems.isEmpty, revealedFallback.count >= 2 {
                MapPolyline(coordinates: revealedFallback)
                    .stroke(Color.cyan.opacity(0.35), style: StrokeStyle(lineWidth: 11, lineCap: .round, lineJoin: .round))
                MapPolyline(coordinates: revealedFallback)
                    .stroke(.cyan, lineWidth: 4.5)
            }

            if startPinVisible, let start = viewModel.routeStartCoordinate {
                Annotation(L10n.tripPointStart, coordinate: start) {
                    routeAnnotationMark(systemName: "flag.fill", color: .green, popped: startPinVisible)
                }
            }

            if endPinVisible, let end = viewModel.routeEndCoordinate {
                Annotation(L10n.tripPointEnd, coordinate: end) {
                    routeAnnotationMark(systemName: "mappin.circle.fill", color: .red, popped: endPinVisible)
                }
            }

            ForEach(Array(sortedStops.enumerated()), id: \.element.persistentModelID) { _, stop in
                if routeRevealProgress >= viewModel.annotationRevealProgress(forStopAt: stop.coordinate) {
                    Annotation(L10n.tripPointStop, coordinate: stop.coordinate) {
                        routeAnnotationMark(systemName: "pause.circle.fill", color: .orange, popped: true)
                    }
                }
            }
        }
        .mapStyle(style.mapStyle)
        .preferredColorScheme(style == .dark ? .dark : nil)
    }

    private func routeAnnotationMark(systemName: String, color: Color, popped: Bool) -> some View {
        Image(systemName: systemName)
            .padding(6)
            .background(color, in: Circle())
            .foregroundStyle(.white)
            .scaleEffect(popped ? 1 : 0.35)
            .opacity(popped ? 1 : 0)
            .shadow(color: color.opacity(0.55), radius: popped ? 8 : 0, y: 1)
            .animation(reduceMotion ? nil : TrailhoundMotion.pinPop, value: popped)
    }

    private var fullscreenMapSheet: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                tripMapView(style: mapStyle, interactive: true)

                VStack(alignment: .trailing, spacing: 8) {
                    compactSpeedLegend

                    Picker("Harita stili", selection: $mapStyle) {
                        Text(L10n.mapStyleLight).tag(TripMapStyle.standard)
                        Text(L10n.mapStyleDark).tag(TripMapStyle.dark)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding()
            }
            .navigationTitle(viewModel.routeSummary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") {
                        showFullscreenMap = false
                    }
                }
            }
            .onAppear {
                if let region = viewModel.mapRegion(fit: .fullscreen) {
                    cameraPosition = .region(region)
                }
            }
        }
    }

    private func renderShareCard() async {
        isRenderingShareCard = true
        defer { isRenderingShareCard = false }

        guard let image = await TripShareCardRenderer.render(
            trip: trip,
            places: places,
            privacyRadius: settings.privacyRadiusMeters
        ) else {
            AppErrorPresenter.shared.present(L10n.string("share.card.error"))
            return
        }
        shareImage = image
        showShareSheet = true
    }

    private func dismissNoteKeyboard() {
        noteFocused = false
        KeyboardDismiss.dismiss()
    }

    private func saveEdits() {
        trip.note = noteText.isEmpty ? nil : noteText
        trip.label = selectedLabel.isEmpty ? nil : selectedLabel
        trip.categoryID = selectedCategoryID
        trip.startAddress = startAddressText.isEmpty ? nil : startAddressText
        trip.endAddress = endAddressText.isEmpty ? nil : endAddressText
        trip.startPlaceName = startPlaceNameText.isEmpty ? nil : startPlaceNameText
        trip.endPlaceName = endPlaceNameText.isEmpty ? nil : endPlaceNameText
        trip.startedAt = editedStartedAt
        if trip.endedAt != nil {
            trip.endedAt = max(editedEndedAt, editedStartedAt)
        }
        applyGPSTrimIfNeeded()
        originalNoteText = noteText
        try? modelContext.save()
    }

    private func applyGPSTrimIfNeeded() {
        guard trimHeadCount > 0 || trimTailCount > 0 else { return }

        var sorted = trip.sortedPoints
        guard sorted.count > trimHeadCount + trimTailCount else { return }

        if trimHeadCount > 0 {
            sorted.removeFirst(trimHeadCount)
        }
        if trimTailCount > 0 {
            sorted.removeLast(trimTailCount)
        }

        for point in trip.points {
            modelContext.delete(point)
        }
        trip.points.removeAll()

        var distance: Double = 0
        var previousLocation: CLLocation?
        for (index, oldPoint) in sorted.enumerated() {
            let point = TripPoint(
                timestamp: oldPoint.timestamp,
                latitude: oldPoint.latitude,
                longitude: oldPoint.longitude,
                sequence: index,
                speedMps: oldPoint.speedMps,
                trip: trip
            )
            trip.points.append(point)
            modelContext.insert(point)

            let location = CLLocation(latitude: oldPoint.latitude, longitude: oldPoint.longitude)
            if let previousLocation {
                distance += location.distance(from: previousLocation)
            }
            previousLocation = location
        }

        trip.distanceMeters = distance
        trip.invalidatePointCaches()
        trimHeadCount = 0
        trimTailCount = 0
    }
}

private struct TripStopEditRow: View {
    @Bindable var stop: TripStop
    @State private var startedAt: Date = Date()
    @State private var durationMinutes: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            DatePicker(L10n.tripStartedAt, selection: $startedAt)
                .onChange(of: startedAt) { _, newValue in
                    stop.startedAt = newValue
                }

            Stepper(
                "\(L10n.duration): \(DateFormatters.formatDuration(stop.durationSeconds))",
                value: $durationMinutes,
                in: 1...240
            )
            .onChange(of: durationMinutes) { _, newValue in
                stop.durationSeconds = TimeInterval(newValue * 60)
            }
        }
        .onAppear {
            startedAt = stop.startedAt
            durationMinutes = max(1, Int(stop.durationSeconds / 60))
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        TripDetailView(trip: PreviewData.sampleTrip)
    }
    .modelContainer(PreviewData.shared.container)
    .environment(NetworkMonitor.shared)
}
