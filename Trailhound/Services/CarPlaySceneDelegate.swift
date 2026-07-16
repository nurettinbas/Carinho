import CarPlay
import UIKit

@MainActor
@Observable
final class CarPlayConnectionHandler: NSObject {
    static let shared = CarPlayConnectionHandler()

    var tripRecordingService: TripRecordingService?

    var onConnectionSnapshotChanged: ((Bool) -> Void)?

    private(set) var isConnected = false
    private weak var interfaceController: CPInterfaceController?

    private override init() {
        super.init()
    }

    func handleConnection(interfaceController: CPInterfaceController) {
        DevLog.shared.log(.carPlay, "Scene didConnect (interfaceController attached)")
        isConnected = true
        self.interfaceController = interfaceController
        onConnectionSnapshotChanged?(true)
        refreshCarPlayUI()
    }

    func handleDisconnection() {
        DevLog.shared.warning(.carPlay, "Scene didDisconnectInterfaceController (not necessarily a real unplug)")
        isConnected = false
        interfaceController = nil
        onConnectionSnapshotChanged?(false)
    }

    @discardableResult
    func readCarPlayConnectionState() -> Bool {
        let probed = probeCarPlaySessionConnected()
        if probed != isConnected {
            DevLog.shared.log(.carPlay, "Scene probe changed: \(isConnected) -> \(probed)")
        }
        isConnected = probed
        return probed
    }

    @discardableResult
    func probeAndSyncConnection() -> Bool {
        let probed = readCarPlayConnectionState()
        onConnectionSnapshotChanged?(probed)
        return probed
    }

    func refreshConnectionSnapshot() {
        _ = probeAndSyncConnection()
    }

    private func probeCarPlaySessionConnected() -> Bool {
        if interfaceController != nil {
            return true
        }

        return UIApplication.shared.connectedScenes.contains { scene in
            guard scene is CPTemplateApplicationScene else { return false }
            switch scene.activationState {
            case .foregroundActive, .foregroundInactive, .background:
                return true
            default:
                return false
            }
        }
    }

    func refreshCarPlayUI() {
        guard let interfaceController, let service = tripRecordingService else { return }

        let isRecording = service.state == .recording
        let isPaused = service.state == .paused
        let distance = DateFormatters.formatDistance(service.currentDistanceMeters)
        let duration = DateFormatters.formatDuration(service.elapsedTime)

        let statusDetail: String = switch service.state {
        case .recording: L10n.carPlayRecording
        case .paused: L10n.recordingPaused
        case .idle: L10n.carPlayIdle
        }

        let items: [CPInformationItem] = [
            CPInformationItem(title: L10n.carPlayStatusTitle, detail: statusDetail),
            CPInformationItem(title: L10n.carPlayDurationTitle, detail: duration),
            CPInformationItem(title: L10n.carPlayDistanceTitle, detail: distance)
        ]

        let template = CPInformationTemplate(title: "Trailhound", layout: .twoColumn, items: items, actions: [])

        if isRecording {
            let pauseAction = CPTextButton(title: L10n.pause, textStyle: .normal) { _ in
                service.pauseRecording()
                Task { @MainActor in
                    self.refreshCarPlayUI()
                }
            }
            let stopAction = CPTextButton(title: L10n.stop, textStyle: .confirm) { _ in
                service.stopManualRecording()
                Task { @MainActor in
                    self.refreshCarPlayUI()
                }
            }
            template.actions = [pauseAction, stopAction]
        } else if isPaused {
            let resumeAction = CPTextButton(title: L10n.resume, textStyle: .confirm) { _ in
                service.resumeRecording()
                Task { @MainActor in
                    self.refreshCarPlayUI()
                }
            }
            let stopAction = CPTextButton(title: L10n.stop, textStyle: .normal) { _ in
                service.stopManualRecording()
                Task { @MainActor in
                    self.refreshCarPlayUI()
                }
            }
            template.actions = [resumeAction, stopAction]
        } else {
            let startAction = CPTextButton(title: L10n.string("Kayıt başlat"), textStyle: .confirm) { _ in
                service.startManualRecording()
                Task { @MainActor in
                    self.refreshCarPlayUI()
                }
            }
            template.actions = [startAction]
        }

        interfaceController.setRootTemplate(template, animated: true, completion: nil)
    }
}

final class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didConnect interfaceController: CPInterfaceController
    ) {
        Task { @MainActor in
            AppServices.bootstrapRecordingIfNeeded()
            CarPlayConnectionHandler.shared.handleConnection(interfaceController: interfaceController)
        }
    }

    func templateApplicationScene(
        _ templateApplicationScene: CPTemplateApplicationScene,
        didDisconnectInterfaceController interfaceController: CPInterfaceController
    ) {
        Task { @MainActor in
            AppServices.bootstrapRecordingIfNeeded()
            CarPlayConnectionHandler.shared.handleDisconnection()
        }
    }
}
