import Foundation

public enum SharedL10n {
    private static let preferredLanguageKey = "preferredLanguageCode"

    public static var preferredLanguageCode: String? {
        RecordingControlBridge.sharedDefaults().string(forKey: preferredLanguageKey)
    }

    public static func text(_ key: String, bundle: Bundle = .main) -> String {
        if let code = preferredLanguageCode, !code.isEmpty,
           let path = bundle.path(forResource: code, ofType: "lproj"),
           let localizedBundle = Bundle(path: path) {
            let localized = localizedBundle.localizedString(forKey: key, value: key, table: nil)
            if localized != key { return localized }
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
