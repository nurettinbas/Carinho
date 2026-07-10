import AppIntents
import SwiftData
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService
    @Environment(MotionActivityService.self) private var motionActivityService
    @Environment(TripRecordingService.self) private var tripRecordingService
    @Environment(BluetoothTriggerService.self) private var bluetoothService
    @Environment(GeocodingRetryService.self) private var geocodingRetryService
    @Query private var places: [SavedPlace]
    @Query(sort: \Trip.startedAt, order: .reverse) private var trips: [Trip]
    @Bindable private var settings = AppSettings.shared

    @State private var exportURL: URL?
    @State private var showExportSheet = false
    @State private var showCarPairing = false

    @FocusState private var focusedField: SettingsFocusedField?

    var body: some View {
        Form {
            Section {
                LocationPermissionBanner()
            }
            .listRowBackground(Color.clear)

            Section(L10n.settingsRecordingSection) {
                Toggle(L10n.settingsAutoRecording, isOn: $settings.autoRecordingEnabled)
                    .onChange(of: settings.autoRecordingEnabled) { _, enabled in
                        tripRecordingService.refreshAutoRecording(enabled: enabled)
                    }
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
                    title: L10n.settingsIdleTimeout,
                    value: Int(settings.idleTimeoutSeconds),
                    range: 30...300,
                    step: 15
                ) { settings.idleTimeoutSeconds = TimeInterval($0) }

                sensitivityRow(
                    title: L10n.settingsLowSpeedStop,
                    value: Int(settings.lowSpeedStopSeconds),
                    range: 30...300,
                    step: 15
                ) { settings.lowSpeedStopSeconds = TimeInterval($0) }

                sensitivityRow(
                    title: L10n.settingsRecordingStartSpeed,
                    value: Int(settings.recordingStartSpeedKmh),
                    range: 5...40,
                    step: 1
                ) { settings.recordingStartSpeedKmh = Double($0) }

                sensitivityRow(
                    title: L10n.settingsRecordingStopSpeed,
                    value: Int(settings.recordingStopSpeedKmh),
                    range: 2...20,
                    step: 1
                ) { settings.recordingStopSpeedKmh = Double($0) }

                sensitivityRow(
                    title: L10n.settingsStopSpeed,
                    value: Int(settings.stopSpeedKmh),
                    range: 1...10,
                    step: 1
                ) { settings.stopSpeedKmh = Double($0) }

                sensitivityRow(
                    title: L10n.settingsStopMinimumDistance,
                    value: Int(settings.stopMinimumDistanceMeters),
                    range: 50...1000,
                    step: 50
                ) { settings.stopMinimumDistanceMeters = Double($0) }

                sensitivityRow(
                    title: L10n.settingsStopMinimumDuration,
                    value: Int(settings.stopMinimumDurationSeconds),
                    range: 60...600,
                    step: 30
                ) { settings.stopMinimumDurationSeconds = TimeInterval($0) }

                sensitivityRow(
                    title: L10n.settingsTripStopMinimumDuration,
                    value: Int(settings.tripStopMinimumDurationSeconds),
                    range: 60...900,
                    step: 30
                ) { settings.tripStopMinimumDurationSeconds = TimeInterval($0) }
            }

            Section(L10n.settingsFavoritePlaces) {
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
            }

            Section(L10n.settingsVehiclePairingSection) {
                if let activeVehicle = VehiclePairingService.activeVehicle(in: modelContext) {
                    LabeledContent(L10n.settingsPairedVehicle, value: activeVehicle.name)
                    LabeledContent(L10n.settingsConnectionType, value: connectionTypeLabel(for: activeVehicle))
                    LabeledContent(L10n.settingsConnectionStatus) {
                        let connected = isVehicleConnected(activeVehicle)
                        Text(connected ? L10n.settingsConnected : L10n.settingsDisconnected)
                            .foregroundStyle(connected ? .green : .secondary)
                    }
                    Button(L10n.settingsChangeVehicle) {
                        showCarPairing = true
                    }
                    Button(L10n.settingsRemovePairing, role: .destructive) {
                        VehiclePairingService.unpair(in: modelContext)
                    }
                } else if let carName = settings.pairedVehicleName {
                    LabeledContent(L10n.settingsPairedVehicle, value: carName)
                    if let type = settings.pairedVehicleType {
                        LabeledContent(L10n.settingsConnectionType, value: type == .carPlay ? L10n.vehiclePairingCarPlay : L10n.vehiclePairingBluetooth)
                    }
                    LabeledContent(L10n.settingsConnectionStatus) {
                        let connected = settings.pairedVehicleType == .carPlay
                            ? CarPlayConnectionHandler.shared.isConnected
                            : bluetoothService.isCarConnected
                        Text(connected ? L10n.settingsConnected : L10n.settingsDisconnected)
                            .foregroundStyle(connected ? .green : .secondary)
                    }
                    Button(L10n.settingsChangeVehicle) {
                        showCarPairing = true
                    }
                    Button(L10n.settingsRemovePairing, role: .destructive) {
                        VehiclePairingService.unpair(in: modelContext)
                    }
                } else {
                    Text(L10n.settingsPairVehicleHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(L10n.settingsDefineVehicle) {
                        showCarPairing = true
                    }
                }
            }

            CategoryManagementView(focusedField: $focusedField)

            VehicleManagementView(focusedField: $focusedField)

            Section(L10n.settingsLanguageSection) {
                Picker(L10n.settingsLanguagePicker, selection: Binding(
                    get: { settings.preferredLanguageCode ?? "system" },
                    set: { settings.preferredLanguageCode = $0 == "system" ? nil : $0 }
                )) {
                    Text(L10n.settingsLanguageSystem).tag("system")
                    Text(L10n.settingsLanguageTurkish).tag("tr")
                    Text(L10n.settingsLanguageEnglish).tag("en")
                }
            }

            Section(L10n.settingsFuelSection) {
                LabeledContent(L10n.settingsFuelConsumption) {
                    TextField("L/100km", value: $settings.fuelLitersPer100km, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .fuelConsumption)
                }
                LabeledContent(L10n.settingsFuelPrice) {
                    TextField("TL", value: $settings.fuelPricePerLiter, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .fuelPrice)
                }
            }

            Section(L10n.settingsPrivacySection) {
                Toggle(L10n.settingsAppLock, isOn: $settings.appLockEnabled)
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
                    Text(locationAuthLabel(locationService.authorizationState))
                }
                if !locationService.canRecordInBackground {
                    Text(L10n.settingsBackgroundLocationHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                LabeledContent(L10n.settingsMotionPermission) {
                    Text(motionActivityService.isAuthorized ? L10n.settingsPermissionGranted : L10n.settingsPermissionRequired)
                }
                Button(L10n.settingsRequestLocationPermission) { locationService.requestPermission() }
                Button(L10n.settingsRequestMotionPermission) { motionActivityService.requestPermission() }
                Button(L10n.settingsOpenSystemSettings) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section(L10n.settingsCarPlaySection) {
                LabeledContent(L10n.settingsCarPlayStatus) {
                    Text(CarPlayConnectionHandler.shared.isConnected ? L10n.settingsConnected : L10n.settingsDisconnected)
                }
                Text(L10n.settingsCarPlayHint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(L10n.settingsBackupSection) {
                Button(L10n.settingsExportJSON) { export(format: .json) }
                Button(L10n.settingsExportCSV) { export(format: .csv) }
                Button(L10n.settingsExportGPX) { export(format: .gpx) }
                Button(L10n.settingsExportKML) { export(format: .kml) }
                Button(L10n.settingsExportMonthlyPDF) { exportMonthlyPDF() }
            }

            Section(L10n.settingsDemoSection) {
                Button(L10n.settingsDemoTrip) {
                    MockTripSeeder.insertSampleTrip(into: modelContext)
                }
            }

            Section(L10n.settingsAboutSection) {
                LabeledContent(L10n.settingsVersion, value: "1.1.0")
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
            motionActivityService.refreshAuthorizationStatus()
            bluetoothService.refreshMonitoring()
            runCleanupIfNeeded()
            Task { await geocodingRetryService.retryPendingTrips(in: modelContext) }
        }
        .sheet(isPresented: $showExportSheet) {
            if let exportURL {
                ExportActivityShareSheet(items: [exportURL])
            }
        }
        .sheet(isPresented: $showCarPairing) {
            CarPairingSheet()
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("carinho-export.\(fileExtension)")
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

    private func exportMonthlyPDF() {
        let completed = trips.filter { $0.endedAt != nil }
        let businessTrips = TripReportPDF.businessTrips(in: completed)
        guard !businessTrips.isEmpty else {
            AppErrorPresenter.shared.present(L10n.pdfNoBusinessTrips)
            return
        }
        guard let data = TripReportPDF.generateMonthlyWorkReport(
            trips: completed,
            places: places,
            privacyRadius: settings.privacyRadiusMeters
        ) else {
            AppErrorPresenter.shared.present(L10n.pdfGenerateFailed)
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("carinho-work-report.pdf")
        do {
            try data.write(to: url)
            exportURL = url
            showExportSheet = true
        } catch {
            AppErrorPresenter.shared.present(error.localizedDescription)
        }
    }

    private func connectionTypeLabel(for vehicle: VehicleProfile) -> String {
        switch vehicle.connectionKind {
        case .carPlay: L10n.vehiclePairingCarPlay
        case .bluetooth: L10n.vehiclePairingBluetooth
        case .none: L10n.vehiclePairingNoConnection
        }
    }

    private func isVehicleConnected(_ vehicle: VehicleProfile) -> Bool {
        switch vehicle.connectionKind {
        case .carPlay:
            CarPlayConnectionHandler.shared.isConnected
        case .bluetooth:
            bluetoothService.isCarConnected
        case .none:
            false
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
        value: Int,
        range: ClosedRange<Int>,
        step: Int,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Stepper(value: Binding(
                get: { value },
                set: { onChange(min(max($0, range.lowerBound), range.upperBound)) }
            ), in: range, step: step) {
                EmptyView()
            }
            .labelsHidden()
        }
    }

    private func locationAuthLabel(_ state: LocationService.AuthorizationState) -> String {
        switch state {
        case .notDetermined: L10n.settingsLocationNotDetermined
        case .authorizedWhenInUse: L10n.settingsLocationWhenInUse
        case .authorizedAlways: L10n.settingsLocationAlways
        case .denied: L10n.settingsLocationDenied
        case .restricted: L10n.settingsLocationRestricted
        }
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
        .environment(MotionActivityService())
        .environment(PreviewData.shared.recordingService)
        .environment(BluetoothTriggerService())
        .environment(GeocodingRetryService(geocodingService: GeocodingService()))
}
