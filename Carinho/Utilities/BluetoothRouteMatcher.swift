import Foundation

struct BluetoothRouteCandidate: Equatable {
    let uid: String?
    let name: String
    let portTypeLabel: String

    var normalizedName: String {
        Self.normalize(name)
    }

    /// Primary key used for legacy storage: UID when available, otherwise normalized name.
    var primaryIdentifier: String {
        if let uid, !uid.isEmpty { return uid }
        return normalizedName
    }

    var debugLabel: String {
        "\(name) (\(portTypeLabel))"
    }

    static func normalize(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct BluetoothPairingIdentity: Equatable {
    let uid: String?
    let displayName: String?
    let legacyIdentifier: String?

    var normalizedName: String? {
        displayName.map(BluetoothRouteCandidate.normalize)
    }

    init(uid: String?, displayName: String?, legacyIdentifier: String? = nil) {
        self.uid = uid?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.displayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        self.legacyIdentifier = legacyIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
    }
}

enum BluetoothRouteMatchMethod: Equatable {
    case uid
    case name
    case legacyIdentifier
    case lastKnownVehicle
}

enum BluetoothRouteMatcher {
    /// Resolves a connected route against stored pairing data.
    /// Priority: UID → display name → legacy identifier → last-known vehicle fallback.
    static func match(
        candidate: BluetoothRouteCandidate,
        pairing: BluetoothPairingIdentity,
        allowLastKnownVehicleFallback: Bool
    ) -> BluetoothRouteMatchMethod? {
        if let uid = pairing.uid, let candidateUID = candidate.uid, uid == candidateUID {
            return .uid
        }

        if let pairedName = pairing.normalizedName, pairedName == candidate.normalizedName {
            return .name
        }

        if let legacy = pairing.legacyIdentifier {
            if legacy == candidate.primaryIdentifier { return .legacyIdentifier }
            if let candidateUID = candidate.uid, legacy == candidateUID { return .legacyIdentifier }
            if legacy == candidate.normalizedName { return .name }
        }

        if allowLastKnownVehicleFallback {
            return .lastKnownVehicle
        }

        return nil
    }

    static func matches(
        candidate: BluetoothRouteCandidate,
        pairing: BluetoothPairingIdentity,
        allowLastKnownVehicleFallback: Bool
    ) -> Bool {
        match(
            candidate: candidate,
            pairing: pairing,
            allowLastKnownVehicleFallback: allowLastKnownVehicleFallback
        ) != nil
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
