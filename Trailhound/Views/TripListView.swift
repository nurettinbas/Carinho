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
    @Namespace private var tripMorphNamespace
    @State private var morphingTripID: UUID?
    @State private var endCredits: RecordingEndCreditsSnapshot?
    /// How far the floating blue bar has slid down toward the trip list.
    @State private var creditsSlideY: CGFloat = 0
    @State private var isCreditsSliding = false
    @State private var listLandingMinY: CGFloat = 0
    @State private var creditsCardAnchor = CreditsCardAnchor()
    /// Pinned at Stop so overlay keeps the live recording card's exact frame.
    @State private var pinnedCreditsCardAnchor = CreditsCardAnchor()
    /// Armed before recording state flips so entrance anim can't lose the race on device.
    @State private var coldOpenArmed = false
    @State private var coldOpenTripID: UUID?

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

            if recordingService.state.isActiveSession, endCredits == nil {
                Section {
                    ActiveTripView(
                        morphNamespace: tripMorphNamespace,
                        morphID: recordingService.activeTripID,
                        playEntranceReveal: coldOpenArmed,
                        onEntranceFinished: finishColdOpen,
                        onStop: beginEndCredits
                    )
                    .id(recordingService.activeTripID)
                    .transition(.opacity)
                    .background {
                        GeometryReader { geo in
                            let frame = geo.frame(in: .global)
                            Color.clear.preference(
                                key: CreditsCardAnchorKey.self,
                                value: CreditsCardAnchor(
                                    minX: frame.minX,
                                    minY: frame.minY,
                                    width: frame.width
                                )
                            )
                        }
                    }
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
                TripFilterChips(selectedCategoryID: $selectedCategoryID)
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: CreditsListLandingYKey.self,
                                // Land just under the filters — top of the trip list.
                                value: geo.frame(in: .global).maxY + 6
                            )
                        }
                    }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if completedTrips.isEmpty {
                if !recordingService.state.isActiveSession, endCredits == nil, coldOpenTripID == nil {
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
                            // Keep the new trip hidden until the blue bar finishes sliding onto it.
                            if endCredits?.tripID != trip.id {
                                tripRow(for: trip)
                            }
                        }
                    }
                }
                .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: completedTrips.count)
            }
        }
        .listSectionSpacing(12)
        .onPreferenceChange(CreditsListLandingYKey.self) { listLandingMinY = $0 }
        .onPreferenceChange(CreditsCardAnchorKey.self) { newValue in
            if newValue.width > 0 {
                creditsCardAnchor = newValue
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
            beginColdOpenIfNeeded(onlyIfRecentlyStarted: true)
        }
        .onChange(of: recordingService.state) { _, newState in
            if !newState.isActiveSession {
                refreshOrphans()
                coldOpenArmed = false
                coldOpenTripID = nil
            }
        }
        .onChange(of: recordingService.state.isActiveSession) { wasActive, isActive in
            if isActive {
                // New recording must never be blocked by a stuck credits card.
                if endCredits != nil {
                    endCredits = nil
                }
            }
            if !wasActive, isActive, endCredits == nil {
                beginColdOpenIfNeeded()
            }
            // Vehicle auto-stop (and other external stops) still get a light morph —
            // full credits play only for manual Stop.
            if wasActive, !isActive, endCredits == nil, morphingTripID == nil,
               let newest = completedTrips.first,
               let endedAt = newest.endedAt,
               Date().timeIntervalSince(endedAt) < 2.5 {
                morphingTripID = newest.id
                clearMorphingTripSoon(delayMilliseconds: reduceMotion ? 50 : 700)
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
                    Button {
                        coldOpenArmed = true
                        if recordingService.startManualRecording(),
                           let tripID = recordingService.activeTripID {
                            coldOpenTripID = tripID
                        } else {
                            coldOpenArmed = false
                            coldOpenTripID = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "record.circle")
                            Text(L10n.string("action.start"))
                        }
                    }
                    .transition(.opacity)
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
        .animation(reduceMotion ? nil : TrailhoundMotion.cardSpring, value: morphingTripID)
        .overlay {
            if let endCredits {
                GeometryReader { geo in
                    let containerFrame = geo.frame(in: .global)
                    let anchor = pinnedCreditsCardAnchor.width > 0
                        ? pinnedCreditsCardAnchor
                        : creditsCardAnchor
                    let startY = anchor.minY > 0
                        ? anchor.minY - containerFrame.minY
                        : 12
                    let xOffset = anchor.minX > 0
                        ? anchor.minX - containerFrame.minX
                        : 0

                    Group {
                        if anchor.width > 0 {
                            RecordingEndCreditsView(
                                snapshot: endCredits,
                                reduceMotion: reduceMotion,
                                onFinished: startCreditsSlideIntoList
                            )
                            .frame(width: anchor.width)
                        } else {
                            RecordingEndCreditsView(
                                snapshot: endCredits,
                                reduceMotion: reduceMotion,
                                onFinished: startCreditsSlideIntoList
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal)
                        }
                    }
                    .id(endCredits.sessionID)
                    .offset(x: xOffset, y: startY + creditsSlideY)
                }
                .allowsHitTesting(false)
                .zIndex(50)
            }
        }
    }

    @ViewBuilder
    private func tripRow(for trip: Trip) -> some View {
        let isMorphing = morphingTripID == trip.id
        Group {
            if isMergeMode {
                Button {
                    toggleMergeSelection(trip.id)
                } label: {
                    HStack {
                        Image(systemName: mergeSelection.contains(trip.id) ? "checkmark.circle.fill" : "circle")
                            .accessibilityLabel(mergeSelection.contains(trip.id) ? "Seçili" : "Seçili değil")
                        TripRowView(
                            trip: trip,
                            places: places,
                            privacyRadius: settings.privacyRadiusMeters,
                            morphNamespace: tripMorphNamespace,
                            morphID: morphingTripID,
                            emphasizeLanding: isMorphing
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
            } else {
                NavigationLink(value: trip.id) {
                    TripRowView(
                        trip: trip,
                        places: places,
                        privacyRadius: settings.privacyRadiusMeters,
                        morphNamespace: tripMorphNamespace,
                        morphID: morphingTripID,
                        emphasizeLanding: isMorphing
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .matchedGeometryEffectIfAvailable(
            id: isMorphing ? trip.id : nil,
            namespace: tripMorphNamespace,
            isSource: false
        )
        .transition(.opacity)
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

    private func beginColdOpenIfNeeded(onlyIfRecentlyStarted: Bool = false) {
        guard endCredits == nil,
              recordingService.state.isActiveSession,
              let tripID = recordingService.activeTripID
        else { return }

        // Already armed for this trip.
        if coldOpenTripID == tripID, coldOpenArmed { return }

        if onlyIfRecentlyStarted {
            guard let startedAt = recordingService.recordingStartedAt,
                  Date().timeIntervalSince(startedAt) < 2.0
            else { return }
        }

        coldOpenArmed = true
        coldOpenTripID = tripID
    }

    private func finishColdOpen() {
        coldOpenArmed = false
        // Only clear once this trip's entrance finished — don't block a newer start.
        if let active = recordingService.activeTripID, coldOpenTripID == active {
            coldOpenTripID = nil
        } else if coldOpenTripID != nil, recordingService.activeTripID == nil {
            coldOpenTripID = nil
        }
    }

    private func beginEndCredits() {
        guard let tripID = recordingService.activeTripID else {
            recordingService.stopManualRecording()
            return
        }

        resetTripFiltersToAll()

        let snapshot = RecordingEndCreditsSnapshot(
            sessionID: UUID(),
            tripID: tripID,
            durationText: DateFormatters.formatDuration(recordingService.elapsedTime),
            distanceText: DateFormatters.formatDistance(recordingService.currentDistanceMeters),
            coordinates: recordingService.liveBreadcrumbCoordinates
        )

        morphingTripID = tripID
        coldOpenArmed = false
        coldOpenTripID = nil
        creditsSlideY = 0
        isCreditsSliding = false
        pinnedCreditsCardAnchor = creditsCardAnchor

        if reduceMotion {
            recordingService.stopManualRecording()
            endCredits = nil
            clearMorphingTripSoon(delayMilliseconds: 50)
            return
        }

        endCredits = snapshot
        recordingService.stopManualRecording()

        let sessionID = snapshot.sessionID
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            if endCredits?.sessionID == sessionID, !isCreditsSliding {
                startCreditsSlideIntoList()
            }
        }
    }

    private func resetTripFiltersToAll() {
        guard selectedCategoryID != nil else { return }

        if reduceMotion {
            selectedCategoryID = nil
        } else {
            withAnimation(TrailhoundMotion.cardSpring) {
                selectedCategoryID = nil
            }
        }
    }

    private func startCreditsSlideIntoList() {
        guard endCredits != nil, !isCreditsSliding else { return }

        let startGlobal = pinnedCreditsCardAnchor.minY > 0
            ? pinnedCreditsCardAnchor.minY
            : creditsCardAnchor.minY
        let measured = listLandingMinY - startGlobal
        let distance = measured > 40 ? measured : 140

        isCreditsSliding = true

        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            creditsSlideY = distance
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(560))
            // Swap overlay → real row with no List insert morph / empty-cell fade.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                endCredits = nil
                creditsSlideY = 0
                isCreditsSliding = false
                pinnedCreditsCardAnchor = CreditsCardAnchor()
            }
            TrailhoundHaptics.selection()
            clearMorphingTripSoon(delayMilliseconds: 900)
        }
    }

    private func clearMorphingTripSoon(delayMilliseconds: Int = 700) {
        let clearingID = morphingTripID
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delayMilliseconds))
            if morphingTripID == clearingID {
                morphingTripID = nil
            }
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

private struct CreditsCardAnchor: Equatable {
    var minX: CGFloat = 0
    var minY: CGFloat = 0
    var width: CGFloat = 0
}

private struct CreditsCardAnchorKey: PreferenceKey {
    static var defaultValue: CreditsCardAnchor { CreditsCardAnchor() }
    static func reduce(value: inout CreditsCardAnchor, nextValue: () -> CreditsCardAnchor) {
        let next = nextValue()
        if next.width > 0 {
            value = next
        }
    }
}

private struct CreditsListLandingYKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    NavigationStack { TripListView() }
        .modelContainer(PreviewData.shared.container)
        .environment(PreviewData.shared.recordingService)
}
