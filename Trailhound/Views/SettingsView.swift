import AppIntents
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService
    @Environment(TripRecordingService.self) private var tripRecordingService
    @Environment(GeocodingRetryService.self) private var geocodingRetryService
    @Environment(AppLockService.self) private var appLockService
    @Query private var places: [SavedPlace]
    @Query(sort: \Trip.startedAt, order: .reverse) private var trips: [Trip]
    @Bindable private var settings = AppSettings.shared

    @State private var exportURL: URL?
    @State private var showExportSheet = false
    @State private var isExporting = false
    @State private var showAppLockUnavailableAlert = false
    @State private var showShortcutsAutomationGuide = false
    @State private var versionTapCount = 0

    @FocusState private var focusedField: SettingsFocusedField?

    var body: some View {
        Form {
            Section {
                LocationPermissionBanner()
            }
            .listRowBackground(Color.clear)

            Section(L10n.settingsRecordingSection) {
                Toggle(L10n.settingsRecordingSounds, isOn: $settings.recordingSoundsEnabled)
                Text(L10n.settingsSiriShortcutsHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ShortcutsLink()
                    .shortcutsLinkStyle(.automaticOutline)
                    .accessibilityLabel(L10n.settingsSiriShortcutsLink)
                Button {
                    showShortcutsAutomationGuide = true
                } label: {
                    Label(L10n.settingsShortcutsAutomationGuide, systemImage: "bolt.horizontal.circle")
                }
            }

            Section(L10n.settingsRecordingSensitivitySection) {
                sensitivityGrid
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section {
                if places.isEmpty {
                    Text(L10n.settingsFavoritePlacesEmpty)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(places) { place in
                    NavigationLink {
                        PlacePickerView(editingPlace: place)
                    } label: {
                        HStack {
                            Image(systemName: place.kind.systemImage)
                            VStack(alignment: .leading) {
                                Text(place.name)
                                Text(place.kind.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deletePlaces)

                NavigationLink(L10n.settingsAddPlace) {
                    PlacePickerView()
                }
            } header: {
                Text(L10n.settingsFavoritePlaces)
            } footer: {
                Text(L10n.settingsFavoritePlacesHint)
            }

            CategoryManagementView(focusedField: $focusedField)

            Section {
                Button(L10n.settingsOpenSystemSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } header: {
                Text(L10n.settingsLanguageSection)
            } footer: {
                Text(L10n.settingsLanguageSystemHint)
            }

            Section(L10n.settingsFuelSection) {
                LabeledContent(L10n.settingsFuelPrice) {
                    TextField("TL", value: $settings.fuelPricePerLiter, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .fuelPrice)
                }
                Text(L10n.settingsFuelHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.settingsPrivacySection) {
                Toggle(L10n.settingsAppLock, isOn: appLockEnabledBinding)
                Toggle(L10n.settingsConfirmExternalStart, isOn: $settings.confirmExternalRecordingStart)
                LabeledContent(L10n.settingsPrivacyRadius) {
                    TextField("metre", value: $settings.privacyRadiusMeters, format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .privacyRadius)
                }
                Toggle(L10n.settingsBlurExport, isOn: $settings.blurExportCoordinates)
                Picker(L10n.settingsAutoDelete, selection: $settings.autoDeleteDays) {
                    Text(L10n.settingsAutoDeleteNever).tag(0)
                    Text("30 gün").tag(30)
                    Text("90 gün").tag(90)
                    Text("365 gün").tag(365)
                }
            }

            Section(L10n.settingsPermissionsSection) {
                LabeledContent(L10n.settingsLocationPermission) {
                    LocationPermissionBadge(state: locationService.authorizationState)
                }
                if !locationService.canRecordInBackground {
                    Text(L10n.settingsBackgroundLocationHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Button(L10n.settingsRequestLocationPermission) { locationService.requestPermission() }
                Button(L10n.settingsOpenSystemSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }


            Section(L10n.settingsBackupSection) {
                Button(L10n.settingsExportJSON) { export(format: .json) }
                    .disabled(isExporting)
                Button(L10n.settingsExportCSV) { export(format: .csv) }
                    .disabled(isExporting)
                Button(L10n.settingsExportGPX) { export(format: .gpx) }
                    .disabled(isExporting)
                Button(L10n.settingsExportKML) { export(format: .kml) }
                    .disabled(isExporting)
            }

            Section(L10n.settingsAboutSection) {
                LabeledContent(L10n.settingsVersion, value: "1.1.0")
                    .contentShape(Rectangle())
                    .onTapGesture {
                        versionTapCount += 1
                        if versionTapCount >= 5 {
                            settings.developerModeEnabled.toggle()
                            versionTapCount = 0
                        }
                    }
                if settings.developerModeEnabled {
                    Toggle(L10n.settingsDeveloperMode, isOn: $settings.developerModeEnabled)
                }
                Text(L10n.settingsAboutPrivacy)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.settingsTitle)
        .dismissKeyboardOnTap(focus: $focusedField)
        .dismissKeyboardOnScroll()
        .keyboardDoneToolbar()
        .onAppear {
            runCleanupIfNeeded()
            Task { await geocodingRetryService.retryPendingTrips(in: modelContext) }
        }
        .sheet(isPresented: $showExportSheet) {
            if let exportURL {
                ExportActivityShareSheet(items: [exportURL])
            }
        }
        .sheet(isPresented: $showShortcutsAutomationGuide) {
            PairingShortcutsAutomationGuideView()
        }
        .alert(L10n.appLockUnavailableTitle, isPresented: $showAppLockUnavailableAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.appLockUnavailable)
        }
        .overlay {
            if isExporting {
                ZStack {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                    VStack(spacing: 14) {
                        ProgressView()
                            .controlSize(.large)
                        Text(L10n.settingsExportPreparing)
                            .font(.subheadline.weight(.medium))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExporting)
    }

    private enum ExportFormat {
        case json, csv, gpx, kml

        var fileExtension: String {
            switch self {
            case .json: "json"
            case .csv: "csv"
            case .gpx: "gpx"
            case .kml: "kml"
            }
        }

        var exportFileFormat: ExportService.FileFormat {
            switch self {
            case .json: .json
            case .csv: .csv
            case .gpx: .gpx
            case .kml: .kml
            }
        }
    }

    private func export(format: ExportFormat) {
        guard !isExporting else { return }

        isExporting = true
        let completed = trips.filter { $0.endedAt != nil }
        let blurCoordinates = settings.blurExportCoordinates
        let privacyRadius = settings.privacyRadiusMeters
        let savedPlaces = places
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("trailhound-export.\(format.fileExtension)")

        Task { @MainActor in
            let snapshots = ExportService.snapshots(
                from: completed,
                blurCoordinates: blurCoordinates,
                places: savedPlaces,
                privacyRadius: privacyRadius
            )

            do {
                try await Task.detached(priority: .userInitiated) {
                    try ExportService.write(
                        snapshots: snapshots,
                        format: format.exportFileFormat,
                        to: url
                    )
                }.value
                exportURL = url
                showExportSheet = true
            } catch {
                AppErrorPresenter.shared.present(error.localizedDescription)
            }
            isExporting = false
        }
    }


    private func deletePlaces(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(places[index])
        }
        try? modelContext.save()
    }

    private func runCleanupIfNeeded() {
        let days = settings.autoDeleteDays
        guard days > 0 else { return }
        _ = try? TripCleanupService.cleanupOldTrips(in: modelContext, olderThanDays: days)
    }

    private var sensitivityGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            sensitivityCell(
                title: L10n.settingsStopSpeed,
                value: Binding(
                    get: { Int(settings.stopSpeedKmh) },
                    set: { settings.stopSpeedKmh = Double($0) }
                ),
                range: 1...10,
                step: 1
            )

            sensitivityCell(
                title: L10n.settingsStopMinimumDistance,
                value: Binding(
                    get: { Int(settings.stopMinimumDistanceMeters) },
                    set: { settings.stopMinimumDistanceMeters = Double($0) }
                ),
                range: 50...1000,
                step: 50
            )

            sensitivityCell(
                title: L10n.settingsStopMinimumDuration,
                value: Binding(
                    get: { Int(settings.stopMinimumDurationSeconds) },
                    set: { settings.stopMinimumDurationSeconds = TimeInterval($0) }
                ),
                range: 60...600,
                step: 30
            )

            sensitivityCell(
                title: L10n.settingsTripStopMinimumDuration,
                value: Binding(
                    get: { Int(settings.tripStopMinimumDurationSeconds) },
                    set: { settings.tripStopMinimumDurationSeconds = TimeInterval($0) }
                ),
                range: 60...900,
                step: 30
            )
        }
    }

    private func sensitivityCell(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                sensitivityStepButton(systemImage: "minus") {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                }
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue)")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)

                sensitivityStepButton(systemImage: "plus") {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                }
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func sensitivityStepButton(
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .frame(width: 26, height: 26)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var appLockEnabledBinding: Binding<Bool> {
        Binding(
            get: { settings.appLockEnabled },
            set: { newValue in
                if newValue, !appLockService.canUseDeviceAuthentication {
                    settings.appLockEnabled = false
                    showAppLockUnavailableAlert = true
                } else {
                    settings.appLockEnabled = newValue
                }
            }
        )
    }
}

struct ExportActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { SettingsView() }
        .modelContainer(PreviewData.shared.container)
        .environment(LocationService())
        .environment(PreviewData.shared.recordingService)
        .environment(GeocodingRetryService(geocodingService: GeocodingService()))
        .environment(AppLockService())
}
