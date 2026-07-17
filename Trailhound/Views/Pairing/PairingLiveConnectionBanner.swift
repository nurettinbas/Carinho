import SwiftUI
import UIKit

struct PairingLiveConnectionBanner: View {
    let bluetoothService: BluetoothTriggerService
    let refreshToken: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var liveConnection: LiveVehicleConnection {
        // `refreshToken` is read so route/scene refreshes re-evaluate detection
        // without wiping view identity via `.id(...)`.
        _ = refreshToken
        return VehiclePairingService.detectLiveConnection(bluetoothService: bluetoothService)
    }

    var body: some View {
        PairingCardContainer {
            HStack(alignment: .center, spacing: 12) {
                LiveConnectionStatusIcon(
                    isLive: liveConnection.isDetected,
                    reduceMotion: reduceMotion
                )
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.pairingLiveConnectionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    if liveConnection.isDetected {
                        Text(liveConnection.displayLabel())
                            .font(.headline)
                            .lineLimit(2)
                        Text(L10n.pairingAutoStartHint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(L10n.pairingLiveConnectionNone)
                            .font(.headline)
                        Text(L10n.pairingTabWaitingConnection)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .animation(reduceMotion ? nil : TrailhoundMotion.gentle, value: liveConnection.isDetected)
                .contentTransition(.opacity)

                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}

// MARK: - Core Animation status icon

private struct LiveConnectionStatusIcon: UIViewRepresentable {
    var isLive: Bool
    var reduceMotion: Bool

    func makeUIView(context: Context) -> LiveConnectionStatusIconView {
        LiveConnectionStatusIconView()
    }

    func updateUIView(_ uiView: LiveConnectionStatusIconView, context: Context) {
        uiView.apply(isLive: isLive, animated: !reduceMotion)
    }
}

private final class LiveConnectionStatusIconView: UIView {
    private enum Metrics {
        static let size: CGFloat = 44
        static let iconPointSize: CGFloat = 17
        static let glowLineWidth: CGFloat = 2
        static let glowInset: CGFloat = 1
        static let crossfadeDuration: CFTimeInterval = 0.38
        static let pulseDuration: CFTimeInterval = 1.9
    }

    private let discLayer = CALayer()
    private let glowRingLayer = CAShapeLayer()
    private let iconView = UIImageView()

    private var isLive = false
    private var hasConfigured = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = false
        isUserInteractionEnabled = false
        configureLayersIfNeeded()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        configureLayersIfNeeded()

        let bounds = self.bounds
        discLayer.frame = bounds
        discLayer.cornerRadius = bounds.width * 0.5

        let glowBounds = bounds.insetBy(dx: Metrics.glowInset, dy: Metrics.glowInset)
        glowRingLayer.frame = bounds
        glowRingLayer.path = UIBezierPath(ovalIn: glowBounds).cgPath

        iconView.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Resume pulse when returning to a window (e.g. tab reappear).
        if window != nil, isLive {
            startPulseIfNeeded()
        }
    }

    func apply(isLive: Bool, animated: Bool) {
        configureLayersIfNeeded()

        let changed = isLive != self.isLive
        self.isLive = isLive

        let discColor = isLive
            ? UIColor.systemGreen.withAlphaComponent(0.15)
            : UIColor.secondaryLabel.withAlphaComponent(0.12)
        let tint = isLive ? UIColor.systemGreen : UIColor.secondaryLabel
        let symbolName = isLive ? "checkmark.circle.fill" : "car.side"
        let image = UIImage(
            systemName: symbolName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Metrics.iconPointSize, weight: .regular)
        )?.withRenderingMode(.alwaysTemplate)

        if animated, changed {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = Metrics.crossfadeDuration
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            iconView.layer.add(fade, forKey: "iconCrossfade")

            CATransaction.begin()
            CATransaction.setAnimationDuration(Metrics.crossfadeDuration)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
            discLayer.backgroundColor = discColor.cgColor
            CATransaction.commit()
        } else {
            discLayer.backgroundColor = discColor.cgColor
        }

        iconView.image = image
        iconView.tintColor = tint

        glowRingLayer.strokeColor = UIColor.systemGreen.withAlphaComponent(0.55).cgColor
        glowRingLayer.isHidden = !isLive

        if isLive, animated {
            startPulseIfNeeded()
        } else {
            stopPulse()
            glowRingLayer.opacity = isLive ? 0.45 : 0
            glowRingLayer.transform = CATransform3DIdentity
        }
    }

    private func configureLayersIfNeeded() {
        guard !hasConfigured else { return }
        hasConfigured = true

        discLayer.contentsScale = traitCollection.displayScale
        layer.addSublayer(discLayer)

        glowRingLayer.fillColor = UIColor.clear.cgColor
        glowRingLayer.lineWidth = Metrics.glowLineWidth
        glowRingLayer.opacity = 0
        glowRingLayer.isHidden = true
        glowRingLayer.contentsScale = traitCollection.displayScale
        layer.addSublayer(glowRingLayer)

        iconView.contentMode = .center
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(
            pointSize: Metrics.iconPointSize,
            weight: .regular
        )
        addSubview(iconView)
    }

    private func startPulseIfNeeded() {
        guard glowRingLayer.animation(forKey: "softPulse") == nil else { return }

        glowRingLayer.isHidden = false
        glowRingLayer.opacity = 0.35
        glowRingLayer.transform = CATransform3DIdentity

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.22
        opacity.toValue = 0.62

        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 1.14

        let group = CAAnimationGroup()
        group.animations = [opacity, scale]
        group.duration = Metrics.pulseDuration
        group.autoreverses = true
        group.repeatCount = .infinity
        group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        group.isRemovedOnCompletion = false

        glowRingLayer.add(group, forKey: "softPulse")
    }

    private func stopPulse() {
        glowRingLayer.removeAnimation(forKey: "softPulse")
    }
}
