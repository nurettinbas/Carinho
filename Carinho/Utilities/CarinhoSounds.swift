import AVFoundation

@MainActor
enum CarinhoSounds {
    private static var players: [String: AVAudioPlayer] = [:]
    private static var sessionConfigured = false

    static func recordingStarted() {
        play(resource: "trip_start")
    }

    static func recordingStopped() {
        play(resource: "trip_stop")
    }

    private static func play(resource name: String) {
        guard AppSettings.shared.recordingSoundsEnabled else { return }

        do {
            try configureSessionIfNeeded()
            let player: AVAudioPlayer
            if let cached = players[name] {
                player = cached
                player.currentTime = 0
            } else {
                guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }
                player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[name] = player
            }
            player.play()
        } catch {
            // Non-critical feedback; haptics still fire.
        }
    }

    private static func configureSessionIfNeeded() throws {
        guard !sessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        sessionConfigured = true
    }
}
