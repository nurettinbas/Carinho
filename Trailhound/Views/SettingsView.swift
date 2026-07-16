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
    @State private var showAppLockUnavailableAlert = false
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
            }

            Section(L10n.settingsRecordingSensitivitySection) {
                sensitivityRow(
                    title: L10n.settingsStopSpeed,
                    value: Binding(
                        get: { Int(settings.stopSpeedKmh) },
                        set: { settings.stopSpeedKmh = Double($0) }
                    ),
                    range: 1...10,
                    step: 1
                )

                sensitivityRow(
                    title: L10n.settingsStopMinimumDistance,
                    value: Binding(
                        get: { Int(settings.stopMinimumDistanceMeters) },
                        set: { settings.stopMinimumDistanceMeters = Double($0) }
                    ),
                    range: 50...1000,
                    step: 50
                )

                sensitivityRow(
                    title: L10n.settingsStopMinimumDuration,
                    value: Binding(
                        get: { Int(settings.stopMinimumDurationSeconds) },
                        set: { settings.stopMinimumDurationSeconds = TimeInterval($0) }
                    ),
                    range: 60...600,
                    step: 30
                )

                sensitivityRow(
                    title: L10n.settingsTripStopMinimumDuration,
                    value: Binding(
                        get: { Int(settings.tripStopMinimumDurationSeconds) },
                        set: { settings.tripStopMinimumDurationSeconds = TimeInterval($0) }
                    ),
                    range: 60...900,
                    step: 30
                )
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
                Button(L10n.settingsExportCSV) { export(format: .csv) }
                Button(L10n.settingsExportGPX) { export(format: .gpx) }
                Button(L10n.settingsExportKML) { export(format: .kml) }
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
        .alert(L10n.appLockUnavailableTitle, isPresented: $showAppLockUnavailableAlert) {
            Button(L10n.ok, role: .cancel) {}
        } message: {
            Text(L10n.appLockUnavailable)
        }
    }

    private enum ExportFormat { case json, csv, gpx, kml }

    private func export(format: ExportFormat) {
        let completed = trips.filter { $0.endedAt != nil }
        let fileExtension: String
        switch format {
        case .json: fileExtension = "json"
        case .csv: fileExtension = "csv"
        case .gpx: fileExtension = "gpx"
        case .kml: fileExtension = "kml"
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("trailhound-export.\(fileExtension)")
        do {
            switch format {
            case .json:
                let data = try ExportService.exportJSON(trips: completed, blurCoordinates: settings.blurExportCoordinates)
                try data.write(to: url)
            case .csv:
                let csv = ExportService.exportCSV(trips: completed)
                try csv.write(to: url, atomically: true, encoding: .utf8)
            case .gpx:
                let gpx = ExportService.exportGPX(trips: completed, blurCoordinates: settings.blurExportCoordinates)
                try gpx.write(to: url, atomically: true, encoding: .utf8)
            case .kml:
                let kml = ExportService.exportKML(trips: completed, blurCoordinates: settings.blurExportCoordinates)
                try kml.write(to: url, atomically: true, encoding: .utf8)
            }
            exportURL = url
            showExportSheet = true
        } catch {
            AppErrorPresenter.shared.present(error.localizedDescription)
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

    private func sensitivityRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Stepper(value: value, in: range, step: step) {
                EmptyView()
            }
            .labelsHidden()
        }
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
