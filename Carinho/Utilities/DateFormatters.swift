import CoreLocation
import Foundation

enum DateFormatters {
    private static let preferredLanguageKey = "preferredLanguageCode"
    private static let suiteName = "group.com.carinho.app"

    static var currentLocale: Locale {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        if let code = defaults.string(forKey: preferredLanguageKey) {
            return Locale(identifier: code)
        }
        return .current
    }

    static func tripDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }

    static func tripTimeFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = currentLocale
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    static var tripDate: DateFormatter { tripDateFormatter() }
    static var tripTime: DateFormatter { tripTimeFormatter() }

    static func formatDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded()))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    static func formatDistance(_ meters: Double) -> String {
        let kilometers = meters / 1000
        let formatter = MeasurementFormatter()
        formatter.locale = currentLocale
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.maximumFractionDigits = 1
        formatter.numberFormatter.minimumFractionDigits = kilometers >= 10 ? 0 : 1
        let measurement = Measurement(value: kilometers, unit: UnitLength.kilometers)
        return formatter.string(from: measurement)
    }

    static func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        String(format: "%.4f, %.4f", coordinate.latitude, coordinate.longitude)
    }

    static func formatTripDateRange(startedAt: Date, endedAt: Date?) -> String {
        let datePart = tripDate.string(from: startedAt).components(separatedBy: ", ").first ?? tripDate.string(from: startedAt)
        let startTime = tripTime.string(from: startedAt)
        guard let endedAt else { return "\(datePart) · \(startTime)" }
        let endTime = tripTime.string(from: endedAt)
        return "\(datePart) · \(startTime) – \(endTime)"
    }
}
