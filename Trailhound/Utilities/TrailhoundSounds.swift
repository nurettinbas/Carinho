import AVFoundation

@MainActor
enum TrailhoundSounds {
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
            } else {
                guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }
                player = try AVAudioPlayer(contentsOf: url)
                player.volume = 1
                player.prepareToPlay()
                players[name] = player
            }
            player.currentTime = 0
            _ = player.play()
        } catch {
            // Non-critical feedback; haptics still fire.
        }
    }

    private static func configureSessionIfNeeded() throws {
        guard !sessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        // `.playback` ignores the silent switch so recording cues still play in
        // Simulator / when the Mac or device is on mute-ringer. Mix with others
        // so we don't interrupt Music / CarPlay.
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
        sessionConfigured = true
    }
}
