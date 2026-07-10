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
    @State private var didAppear = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sortedStops: [TripStop] {
        trip.stops.sorted { $0.startedAt < $1.startedAt }
    }

    private var viewModel: TripDetailViewModel {
        TripDetailViewModel(trip: trip, places: places, privacyRadius: settings.privacyRadiusMeters)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                tripMapView(style: mapStyle, interactive: true)
                    .onTapGesture {
                        dismissNoteKeyboard()
                    }

                VStack(alignment: .trailing, spacing: 8) {
                    if !networkMonitor.isConnected {
                        Text("Harita karoları için internet gerekir. Rota kayıtlı veriden çizilir.")
                            .font(.caption)
                            .padding(8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    speedLegend

                    Button {
                        showFullscreenMap = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.body.weight(.semibold))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(L10n.mapFullscreen)
                }
                .padding()
            }
            .frame(maxHeight: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    summaryCard

                    if !viewModel.speedSamples.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tripSpeedChart)
                                .font(.subheadline.bold())

                            Chart(viewModel.speedSamples, id: \.id) { sample in
                                AreaMark(
                                    x: .value("Zaman", sample.date),
                                    y: .value("Hız", sample.speedKmh)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.blue.opacity(0.35), Color.blue.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                LineMark(
                                    x: .value("Zaman", sample.date),
                                    y: .value("Hız", sample.speedKmh)
                                )
                                .foregroundStyle(Color.blue)
                                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            }
                            .chartYScale(domain: 0...viewModel.speedChartMaxKmh)
                            .chartYAxisLabel(L10n.speedKmh)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    if !sortedStops.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.tripStopsSection)
                                .font(.subheadline.bold())

                            ForEach(sortedStops, id: \.persistentModelID) { stop in
                                TripStopEditRow(stop: stop)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tripEditTimesSection)
                            .font(.subheadline.bold())

                        DatePicker(L10n.tripStartedAt, selection: $editedStartedAt)

                        if trip.endedAt != nil {
                            DatePicker(L10n.tripEndedAt, selection: $editedEndedAt)
                        }
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tripTrimPointsSection)
                            .font(.subheadline.bold())

                        Stepper(L10n.tripTrimHead, value: $trimHeadCount, in: 0...maxTrimHead)
                        Stepper(L10n.tripTrimTail, value: $trimTailCount, in: 0...maxTrimTail)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tripLocationOverrides)
                            .font(.subheadline.bold())
                        TextField(L10n.tripStartPlaceName, text: $startPlaceNameText)
                            .textFieldStyle(.roundedBorder)
                        TextField(L10n.tripEndPlaceName, text: $endPlaceNameText)
                            .textFieldStyle(.roundedBorder)
                        TextField(L10n.tripStartAddress, text: $startAddressText)
                            .textFieldStyle(.roundedBorder)
                        TextField(L10n.tripEndAddress, text: $endAddressText)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Not")
                            .font(.subheadline.bold())

                        TextField("Not ekle…", text: $noteText, axis: .vertical)
                            .lineLimit(2...4)
                            .focused($noteFocused)
                            .submitLabel(.done)
                            .onSubmit { dismissNoteKeyboard() }
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("Değişiklikleri kaydet") {
                        saveEdits()
                        dismissNoteKeyboard()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)

                    Button {
                        Task { await renderShareCard() }
                    } label: {
                        Group {
                            if isRenderingShareCard {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Label(L10n.share, systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRenderingShareCard)
                }
                .padding()
            }
            .frame(maxHeight: 360)
            .background(.ultraThinMaterial)
            .dismissKeyboardOnScroll()
        }
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : 12)
        .dismissKeyboardOnTap(focus: $noteFocused)
        .navigationTitle("Yolculuk")
        .navigationBarTitleDisplayMode(.inline)
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
            if let region = viewModel.mapRegion {
                cameraPosition = .region(region)
            }
            if reduceMotion {
                didAppear = true
            } else {
                withAnimation(CarinhoMotion.gentle) {
                    didAppear = true
                }
            }
        }
    }

    private var maxTrimHead: Int {
        max(0, trip.sortedPoints.count - trimTailCount - 2)
    }

    private var maxTrimTail: Int {
        max(0, trip.sortedPoints.count - trimHeadCount - 2)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.tripSummary)
                .font(.headline)

            Text(viewModel.dateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(viewModel.routeSummary)
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(Array(viewModel.summaryItems.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(item.value)
                                .font(.subheadline.weight(.medium))
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var speedLegend: some View {
        VStack(alignment: .leading, spacing: 4) {
            legendRow(color: .green, text: L10n.speedLegendSlow)
            legendRow(color: .yellow, text: L10n.speedLegendMedium)
            legendRow(color: .red, text: L10n.speedLegendFast)
        }
        .font(.caption2)
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func legendRow(color: Color, text: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
        }
    }

    @ViewBuilder
    private func tripMapView(style: TripMapStyle, interactive: Bool) -> some View {
        Map(position: $cameraPosition, interactionModes: interactive ? .all : []) {
            ForEach(viewModel.speedColoredSegments) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(
                        segment.color,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .mapOverlayLevel(level: .aboveRoads)
            }

            if viewModel.speedColoredSegments.isEmpty, viewModel.coordinates.count >= 2 {
                MapPolyline(coordinates: viewModel.coordinates)
                    .stroke(.blue, lineWidth: 4)
            }

            if let start = viewModel.coordinates.first {
                Annotation("Başlangıç", coordinate: start) {
                    Image(systemName: "flag.fill")
                        .padding(6)
                        .background(.green, in: Circle())
                        .foregroundStyle(.white)
                }
            }

            if let end = viewModel.coordinates.last, viewModel.coordinates.count > 1 {
                Annotation("Bitiş", coordinate: end) {
                    Image(systemName: "mappin.circle.fill")
                        .padding(6)
                        .background(.red, in: Circle())
                        .foregroundStyle(.white)
                }
            }

            ForEach(Array(trip.stops.enumerated()), id: \.offset) { _, stop in
                Annotation("Mola", coordinate: stop.coordinate) {
                    Image(systemName: "pause.circle.fill")
                        .padding(6)
                        .background(.orange, in: Circle())
                        .foregroundStyle(.white)
                }
            }
        }
        .mapStyle(style.mapStyle)
        .preferredColorScheme(style == .dark ? .dark : nil)
    }

    private var fullscreenMapSheet: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                tripMapView(style: mapStyle, interactive: true)

                VStack(alignment: .trailing, spacing: 8) {
                    speedLegend

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
