import Foundation

enum L10n {
    private static let preferredLanguageKey = "preferredLanguageCode"
    private static let suiteName = "group.com.carinho.app"

    private static var preferredLanguageCode: String? {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        return defaults.string(forKey: preferredLanguageKey)
    }

    static func string(_ key: String.LocalizationValue) -> String {
        if let code = preferredLanguageCode {
            return String(localized: key, locale: Locale(identifier: code))
        }
        return String(localized: key, locale: .current)
    }

    static var tripStartedTitle: String { string("trip.started.title") }
    static var tripStartedBody: String { string("trip.started.body") }
    static var tripEndedTitle: String { string("trip.ended.title") }
    static var tripDiscardedTitle: String { string("trip.discarded.title") }
    static var tripDiscardedBody: String { string("trip.discarded.body") }
    static var recordingStarted: String { string("recording.started") }
    static var categoryPersonal: String { string("category.personal") }
    static var categoryBusiness: String { string("category.business") }
    static var speedKmh: String { string("unit.speed_kmh") }
    static var stop: String { string("action.stop") }
    static var delete: String { string("action.delete") }
    static var share: String { string("action.share") }

    static var notificationsTitle: String { string("notifications.title") }
    static var notificationsEmptyTitle: String { string("notifications.empty.title") }
    static var notificationsEmptyMessage: String { string("notifications.empty.message") }
    static var notificationsMarkAllRead: String { string("notifications.mark_all_read") }
    static var notificationsClearAll: String { string("notifications.clear_all") }

    static var pause: String { string("action.pause") }
    static var resume: String { string("action.resume") }
    static var recordingPaused: String { string("recording.paused") }
    static var settingsRecordingSection: String { string("settings.recording.section") }
    static var settingsAutoRecording: String { string("settings.recording.auto") }
    static var settingsRecordingSounds: String { string("settings.recording.sounds") }
    static var settingsRecordingSensitivitySection: String { string("settings.recording.sensitivity") }
    static var settingsIdleTimeout: String { string("settings.recording.idle_timeout") }
    static var settingsLowSpeedStop: String { string("settings.recording.low_speed_stop") }
    static var settingsRecordingStartSpeed: String { string("settings.recording.start_speed") }
    static var settingsRecordingStopSpeed: String { string("settings.recording.stop_speed") }
    static var settingsStopSpeed: String { string("settings.recording.trip_stop_speed") }
    static var settingsStopMinimumDistance: String { string("settings.recording.min_distance") }
    static var settingsStopMinimumDuration: String { string("settings.recording.min_duration") }
    static var settingsTripStopMinimumDuration: String { string("settings.recording.trip_stop_min_duration") }
    static var tripStopsSection: String { string("trip.stops.section") }
    static var tripEditTimesSection: String { string("trip.edit.times") }
    static var tripTrimPointsSection: String { string("trip.trim.points") }
    static var tripTrimHead: String { string("trip.trim.head") }
    static var tripTrimTail: String { string("trip.trim.tail") }
    static var tripStartedAt: String { string("trip.started_at") }
    static var tripEndedAt: String { string("trip.ended_at") }
    static var orphanStaleNotificationTitle: String { string("orphan.stale.title") }
    static var orphanStaleNotificationBody: String { string("orphan.stale.body") }
    static var all: String { string("filter.all") }
    static var duration: String { string("label.duration") }
    static var currentSpeed: String { string("label.current_speed") }
    static var maxAbbr: String { string("label.max_abbr") }
    static var avgAbbr: String { string("label.avg_abbr") }
    static var carPlayStatusTitle: String { string("carplay.status") }
    static var carPlayDurationTitle: String { string("label.duration") }
    static var carPlayDistanceTitle: String { string("carplay.distance") }
    static var carPlayRecording: String { string("carplay.recording") }
    static var carPlayIdle: String { string("carplay.idle") }
    static var placeHome: String { string("place.home") }
    static var placeWork: String { string("place.work") }
    static var placeOther: String { string("place.other") }
    static var labelWork: String { string("label.work") }
    static var labelMarket: String { string("label.market") }
    static var labelHoliday: String { string("label.holiday") }
    static var labelOther: String { string("label.other") }
    static var sectionToday: String { string("section.today") }
    static var sectionYesterday: String { string("section.yesterday") }
    static var sectionThisWeek: String { string("section.this_week") }
    static var sectionThisMonth: String { string("section.this_month") }
    static var sectionOlder: String { string("section.older") }
    static var searchTrips: String { string("search.trips") }
    static var actionMerge: String { string("action.merge") }
    static var actionCategory: String { string("action.category") }
    static var mapFullscreen: String { string("map.fullscreen") }
    static var mapStyleLight: String { string("map.style.light") }
    static var mapStyleDark: String { string("map.style.dark") }
    static var speedLegendSlow: String { string("speed.legend.slow") }
    static var tripSpeedChart: String { string("trip.speed_chart") }
    static var speedLegendMedium: String { string("speed.legend.medium") }
    static var speedLegendFast: String { string("speed.legend.fast") }
    static var tripSummary: String { string("trip.summary") }
    static var estimatedFuel: String { string("label.estimated_fuel") }
    static var maxSpeed: String { string("label.max_speed") }
    static var fuelPetrol: String { string("fuel.petrol") }
    static var fuelDiesel: String { string("fuel.diesel") }
    static var fuelElectric: String { string("fuel.electric") }
    static var fuelHybrid: String { string("fuel.hybrid") }
    static var tripLocationOverrides: String { string("trip.location.overrides") }
    static var tripStartPlaceName: String { string("trip.start_place_name") }
    static var tripEndPlaceName: String { string("trip.end_place_name") }
    static var tripStartAddress: String { string("trip.start_address") }
    static var tripEndAddress: String { string("trip.end_address") }
    static var placeSuggestionSection: String { string("place.suggestion.section") }
    static var placePickerSelectedLocation: String { string("place.picker.selected_location") }
    static var placePickerMoveMapHint: String { string("place.picker.move_map_hint") }
    static var placePickerUseCurrentLocation: String { string("place.picker.use_current_location") }
    static var placePickerResolvingAddress: String { string("place.picker.resolving_address") }
    static var placePickerNearbySection: String { string("place.picker.nearby_section") }
    static var placePickerUseAddressAsName: String { string("place.picker.use_address_as_name") }
    static var placePickerEditTitle: String { string("place.picker.edit_title") }
    static var placePickerNewTitle: String { string("place.picker.new_title") }
    static var placePickerSave: String { string("place.picker.save") }
    static var settingsFavoritePlaces: String { string("settings.favorite_places") }
    static var settingsAddPlace: String { string("settings.add_place") }

    static var actionRefresh: String { string("action.refresh") }
    static var settingsTitle: String { string("settings.title") }
    static var settingsVehiclePairingSection: String { string("settings.vehicle_pairing.section") }
    static var settingsPairedVehicle: String { string("settings.vehicle_pairing.paired") }
    static var settingsConnectionType: String { string("settings.vehicle_pairing.type") }
    static var settingsConnectionStatus: String { string("settings.vehicle_pairing.connection") }
    static var settingsConnected: String { string("settings.connection.connected") }
    static var settingsDisconnected: String { string("settings.connection.disconnected") }
    static var settingsChangeVehicle: String { string("settings.vehicle_pairing.change") }
    static var settingsRemovePairing: String { string("settings.vehicle_pairing.remove") }
    static var settingsPairVehicleHint: String { string("settings.vehicle_pairing.hint") }
    static var settingsDefineVehicle: String { string("settings.vehicle_pairing.define") }
    static var settingsLanguageSection: String { string("settings.language.section") }
    static var settingsLanguagePicker: String { string("settings.language.picker") }
    static var settingsLanguageSystem: String { string("settings.language.system") }
    static var settingsLanguageTurkish: String { string("settings.language.turkish") }
    static var settingsLanguageEnglish: String { string("settings.language.english") }
    static var settingsFuelSection: String { string("settings.fuel.section") }
    static var settingsFuelConsumption: String { string("settings.fuel.consumption") }
    static var settingsFuelPrice: String { string("settings.fuel.price") }
    static var settingsPrivacySection: String { string("settings.privacy.section") }
    static var settingsAppLock: String { string("settings.privacy.app_lock") }
    static var settingsPrivacyRadius: String { string("settings.privacy.radius") }
    static var settingsBlurExport: String { string("settings.privacy.blur_export") }
    static var settingsAutoDelete: String { string("settings.privacy.auto_delete") }
    static var settingsAutoDeleteNever: String { string("settings.privacy.auto_delete.never") }
    static var settingsPermissionsSection: String { string("settings.permissions.section") }
    static var settingsLocationPermission: String { string("settings.permissions.location") }
    static var settingsMotionPermission: String { string("settings.permissions.motion") }
    static var settingsPermissionGranted: String { string("settings.permissions.granted") }
    static var settingsPermissionRequired: String { string("settings.permissions.required") }
    static var settingsRequestLocationPermission: String { string("settings.permissions.request_location") }
    static var settingsRequestMotionPermission: String { string("settings.permissions.request_motion") }
    static var settingsOpenSystemSettings: String { string("settings.permissions.open_settings") }
    static var settingsBackgroundLocationHint: String { string("settings.permissions.background_location_hint") }
    static var settingsCarPlaySection: String { string("settings.carplay.section") }
    static var settingsCarPlayStatus: String { string("settings.carplay.status") }
    static var settingsCarPlayHint: String { string("settings.carplay.hint") }
    static var settingsBackupSection: String { string("settings.backup.section") }
    static var settingsExportJSON: String { string("settings.backup.json") }
    static var settingsExportCSV: String { string("settings.backup.csv") }
    static var settingsExportGPX: String { string("settings.backup.gpx") }
    static var settingsExportKML: String { string("settings.backup.kml") }
    static var settingsExportMonthlyPDF: String { string("settings.backup.pdf") }
    static var settingsShareFile: String { string("settings.backup.share") }
    static var settingsAboutSection: String { string("settings.about.section") }
    static var settingsVersion: String { string("settings.about.version") }
    static var settingsAboutPrivacy: String { string("settings.about.privacy") }
    static var settingsLocationNotDetermined: String { string("settings.location.not_determined") }
    static var settingsLocationWhenInUse: String { string("settings.location.when_in_use") }
    static var settingsLocationAlways: String { string("settings.location.always") }
    static var settingsLocationDenied: String { string("settings.location.denied") }
    static var settingsLocationRestricted: String { string("settings.location.restricted") }
    static var vehiclePairingTitle: String { string("vehicle.pairing.title") }
    static var vehiclePairingMessage: String { string("vehicle.pairing.message") }
    static var vehiclePairingConnectionType: String { string("vehicle.pairing.connection_type") }
    static var vehiclePairingBluetooth: String { string("vehicle.pairing.bluetooth") }
    static var vehiclePairingCarPlay: String { string("vehicle.pairing.carplay") }
    static var vehiclePairingSkip: String { string("vehicle.pairing.skip") }
    static var vehiclePairingSavedVehicles: String { string("vehicle.pairing.saved_vehicles") }
    static var vehiclePairingConnectedDevice: String { string("vehicle.pairing.connected_device") }
    static var vehiclePairingConfirm: String { string("vehicle.pairing.confirm") }
    static var vehiclePairingWaitingBluetooth: String { string("vehicle.pairing.waiting_bluetooth") }
    static var vehiclePairingCarPlayConnected: String { string("vehicle.pairing.carplay_connected") }
    static var vehiclePairingCarPlayHint: String { string("vehicle.pairing.carplay_hint") }
    static var vehiclePairingNoConnection: String { string("vehicle.pairing.no_connection") }
    static var vehiclePairingMissingConnection: String { string("vehicle.pairing.missing_connection") }
    static var vehicleDefaultName: String { string("vehicle.default_name") }
    static var vehicleAutoTrigger: String { string("vehicle.auto_trigger") }
    static var pdfWorkReportTitle: String { string("pdf.work_report.title") }
    static var pdfColumnDate: String { string("pdf.column.date") }
    static var pdfColumnRoute: String { string("pdf.column.route") }
    static var pdfColumnDistance: String { string("pdf.column.distance") }
    static var pdfColumnDuration: String { string("pdf.column.duration") }
    static var pdfColumnCost: String { string("pdf.column.cost") }
    static var pdfNoBusinessTrips: String { string("pdf.no_business_trips") }
    static var pdfGenerateFailed: String { string("pdf.generate_failed") }
    static var settingsSiriShortcutsHint: String { string("settings.siri.shortcuts_hint") }
    static var settingsSiriShortcutsLink: String { string("settings.siri.shortcuts_link") }
    static var tabTrips: String { string("tab.trips") }
    static var tabStats: String { string("tab.stats") }
    static var tabSettings: String { string("tab.settings") }

    static func pdfWorkReportSummary(distance: String, tripCount: Int, fuelCost: String) -> String {
        let format = string("pdf.work_report.summary")
        return String(format: format, distance, tripCount, fuelCost)
    }


    static func placeSuggestionVisits(_ count: Int) -> String {
        let format = string("place.suggestion.visits")
        return String(format: format, count)
    }

    static func weekSummary(_ distance: String) -> String {
        let format = string("week.summary")
        return String(format: format, distance)
    }

    static func formatSpeedKmh(_ kmh: Double) -> String {
        String(format: "%.0f %@", kmh, speedKmh)
    }

    static func maxSpeedDetail(_ speed: String) -> String {
        let format = string("Maks. hız: %@")
        return String(format: format, speed)
    }
}
