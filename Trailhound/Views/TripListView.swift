import SwiftData
import SwiftUI

struct TripListView: View {
    @Query(sort: \Trip.startedAt, order: .reverse) private var trips: [Trip]
    @Query private var places: [SavedPlace]
    @Query(sort: \UserCategory.sortOrder) private var categories: [UserCategory]
    @Query private var vehicles: [VehicleProfile]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(TripRecordingService.self) private var recordingService
    @Bindable private var settings = AppSettings.shared

    @Bindable private var notificationStore = AppNotificationStore.shared

    @State private var selectedLabel: String?
    @State private var selectedCategoryID: String?
    @State private var mergeSelection = Set<UUID>()
    @State private var isMergeMode = false
    @Bindable private var tabSelection = TabSelection.shared

    @State private var orphanTrips: [TripRecoveryService.OrphanTrip] = []
    @State private var showMergeConfirm = false
    @State private var searchText = ""

    private var hasActiveFilters: Bool {
        selectedLabel != nil || selectedCategoryID != nil || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var completedTrips: [Trip] {
        trips.filter { trip in
            guard trip.endedAt != nil else { return false }
            if let selectedLabel, trip.label != selectedLabel { return false }
            if let selectedCategoryID, trip.categoryID != selectedCategoryID { return false }
            if !TripListViewModel.matchesSearch(
                trip,
                searchText: searchText,
                places: places,
                privacyRadius: settings.privacyRadiusMeters
            ) {
                return false
            }
            return true
        }
    }

    private var groupedTrips: [(section: TripDateSection, trips: [Trip])] {
        TripDateGrouping.groupedSections(from: completedTrips)
    }

    private var weekSummaryText: String {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekTrips = StatsViewModel.trips(
            in: DateInterval(start: weekAgo, end: Date()),
            from: trips.filter { $0.endedAt != nil }
        )
        let stats = StatsViewModel.stats(for: weekTrips)
        return L10n.weekSummary(stats.totalDistanceText)
    }

    private var showsVehicleSetupPrompt: Bool {
        !settings.hasCompletedCarSetup && vehicles.isEmpty
    }

    private var visibleOrphan: TripRecoveryService.OrphanTrip? {
        orphanTrips.first { orphan in
            !orphan.isStale && orphan.id != recordingService.activeTripID
        }
    }

    var body: some View {
        List {
            Section {
                LocationPermissionBanner()
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if showsVehicleSetupPrompt {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.tripListSetupVehicleTitle)
                            .font(.headline)
                        Text(L10n.tripListSetupVehicleMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(L10n.settingsDefineVehicle) {
                            tabSelection.openPairing()
                        }
                        .buttonStyle(.borderedProminent)

                        Button(L10n.vehiclePairingSkip) {
                            settings.skipCarSetup()
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let orphan = visibleOrphan {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L10n.orphanBannerTitle)
                            .font(.headline)
                        Text(L10n.orphanBannerMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button(L10n.orphanResume) {
                                if TripRecoveryService.resumeOrphan(orphan.trip, recordingService: recordingService) {
                                    refreshOrphans()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            Button(L10n.orphanSave) {
                                if TripRecoveryService.finalizeOrphan(orphan.trip, in: modelContext, saveTrip: true) {
                                    refreshOrphans()
                                }
                            }
                            .buttonStyle(.bordered)
                            Button(L10n.delete, role: .destructive) {
                                if TripRecoveryService.deleteOrphan(orphan.trip, in: modelContext) {
                                    refreshOrphans()
                                }
                            }
                        }
                    }
                }
            }

            if recordingService.state.isActiveSession {
                Section {
                    ActiveTripView()
                        .trailhoundCardTransition(reduceMotion: reduceMotion)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if !completedTrips.isEmpty {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.sectionThisWeek)
                                .font(.subheadline.weight(.semibold))
                            Text(weekSummaryText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .numericTextAnimation(value: weekSummaryText)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(L10n.sectionThisWeek). \(weekSummaryText)")
                }
            }

            Section {
                TripFilterChips(selectedLabel: $selectedLabel, selectedCategoryID: $selectedCategoryID)
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if completedTrips.isEmpty {
                if !recordingService.state.isActiveSession {
                    ContentUnavailableView(
                        hasActiveFilters ? "Filtreye uygun yolculuk yok" : "Henüz yolculuk yok",
                        systemImage: "car",
                        description: Text(hasActiveFilters
                            ? "Farklı bir filtre deneyin."
                            : "Manuel başlat veya araca bindiğinde otomatik kayıt başlasın.")
                    )
                    .symbolEffect(.bounce, value: hasActiveFilters)
                    .transition(TrailhoundMotion.fadeScaleTransition(reduceMotion: reduceMotion))
                }
            } else {
                ForEach(groupedTrips, id: \.section) { group in
                    Section(group.section.title) {
                        ForEach(group.trips) { trip in
                            tripRow(for: trip)
                        }
                    }
                }
                .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: completedTrips.count)
            }
        }
        .searchable(text: $searchText, prompt: L10n.searchTrips)
        .navigationDestination(for: UUID.self) { tripID in
            if let trip = trips.first(where: { $0.id == tripID }) {
                TripDetailView(trip: trip)
            } else {
                ContentUnavailableView("Yolculuk bulunamadı", systemImage: "car")
                    .onAppear {
                        DispatchQueue.main.async { dismiss() }
                    }
            }
        }
        .navigationTitle("Trailhound")
        .task {
            refreshOrphans()
            notificationStore.reload()
        }
        .onAppear {
            refreshOrphans()
        }
        .onChange(of: recordingService.state) { _, newState in
            if !newState.isActiveSession {
                refreshOrphans()
            }
        }
        .alert("Yolculukları birleştir", isPresented: $showMergeConfirm) {
            Button("Birleştir") { performMerge() }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("\(mergeSelection.count) yolculuk birleştirilecek.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isMergeMode {
                    Button(L10n.actionMerge) {
                        showMergeConfirm = true
                    }
                    .disabled(mergeSelection.count < 2)
                } else if !recordingService.state.isActiveSession {
                    Button { _ = recordingService.startManualRecording() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "record.circle")
                            Text(L10n.string("action.start"))
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if isMergeMode {
                    Button(L10n.cancel) {
                        isMergeMode = false
                        mergeSelection.removeAll()
                    }
                } else {
                    HStack(spacing: 16) {
                        Button { isMergeMode = true } label: {
                            Image(systemName: "arrow.triangle.merge")
                        }
                        .accessibilityLabel(L10n.actionMerge)

                        NavigationLink {
                            NotificationsListView()
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell")
                                if notificationStore.unreadCount > 0 {
                                    Text("\(min(notificationStore.unreadCount, 99))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(4)
                                        .background(Circle().fill(.red))
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
                        .accessibilityLabel(L10n.notificationsTitle)
                    }
                }
            }
        }
        .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: recordingService.state.isActiveSession)
    }

    @ViewBuilder
    private func tripRow(for trip: Trip) -> some View {
        Group {
            if isMergeMode {
                Button {
                    toggleMergeSelection(trip.id)
                } label: {
                    HStack {
                        Image(systemName: mergeSelection.contains(trip.id) ? "checkmark.circle.fill" : "circle")
                            .accessibilityLabel(mergeSelection.contains(trip.id) ? "Seçili" : "Seçili değil")
                        TripRowView(trip: trip, places: places, privacyRadius: settings.privacyRadiusMeters)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            } else {
                NavigationLink(value: trip.id) {
                    TripRowView(trip: trip, places: places, privacyRadius: settings.privacyRadiusMeters)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                deleteTrip(trip)
            } label: {
                Label(L10n.delete, systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                addToMergeSelection(trip.id)
            } label: {
                Label(L10n.actionMerge, systemImage: "arrow.triangle.merge")
            }
            .tint(.indigo)

            Menu {
                ForEach(categories) { category in
                    Button {
                        updateCategory(trip, categoryID: category.id.uuidString)
                    } label: {
                        Label(category.name, systemImage: category.systemImage)
                    }
                }
            } label: {
                Label(L10n.actionCategory, systemImage: "tag")
            }
            .tint(.orange)
        }
    }

    private func refreshOrphans() {
        orphanTrips = TripRecoveryService.findOrphanTrips(in: modelContext)
        TripRecoveryService.scheduleOrphanStaleNotifications(
            in: modelContext,
            excludingTripID: recordingService.activeTripID
        )
    }

    private func toggleMergeSelection(_ id: UUID) {
        if mergeSelection.contains(id) {
            mergeSelection.remove(id)
        } else {
            mergeSelection.insert(id)
        }
    }

    private func addToMergeSelection(_ id: UUID) {
        isMergeMode = true
        mergeSelection.insert(id)
    }

    private func updateCategory(_ trip: Trip, categoryID: String) {
        trip.categoryID = categoryID
        try? modelContext.save()
    }

    private func deleteTrip(_ trip: Trip) {
        TrailhoundHaptics.destructive()
        TripMapSnapshotCache.shared.remove(for: trip.id)
        modelContext.delete(trip)
        mergeSelection.remove(trip.id)
        try? modelContext.save()
    }

    private func performMerge() {
        TrailhoundHaptics.selection()
        let selected = completedTrips.filter { mergeSelection.contains($0.id) }
        do {
            if let merged = try TripMergeService.merge(trips: selected, into: modelContext) {
                let tripUUID = merged.id
                let container = modelContext.container
                Task { @MainActor in
                    await TripPostProcessor.process(
                        tripUUID: tripUUID,
                        container: container
                    )
                }
            }
            isMergeMode = false
            mergeSelection.removeAll()
        } catch {
            AppErrorPresenter.shared.present(error.localizedDescription)
        }
    }
}

#Preview {
    NavigationStack { TripListView() }
        .modelContainer(PreviewData.shared.container)
        .environment(PreviewData.shared.recordingService)
}
