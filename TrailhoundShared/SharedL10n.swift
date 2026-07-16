import Foundation

public enum SharedL10n {
    public static func text(_ key: String, bundle: Bundle = .main) -> String {
        String(localized: String.LocalizationValue(key), bundle: bundle)
    }
}
