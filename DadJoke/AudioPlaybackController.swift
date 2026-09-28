import AVFoundation

/// Plays a synthesized joke and reports whether it's actually still
/// audible. AVAudioPlayer has no publisher for playback finishing, so this
/// uses the delegate callback -- checking `player.isPlaying` right after
/// calling `play()` is not reliable enough for driving UI (that flag can
/// still read true for a moment after the audio has already ended).
final class AudioPlaybackController: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?

    /// `rate` is a playback-speed multiplier (1.1 = 10% faster), applied
    /// after synthesis rather than by retuning Piper, since it only needs
    /// to affect what the user hears, not the synthesis pipeline itself.
    func play(url: URL, rate: Float = 1.0) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.enableRate = true
            player.rate = rate
            self.player = player
            isPlaying = true
            player.play()
        } catch {
            print("Failed to play synthesized audio: \(error)")
        }
    }
}

extension AudioPlaybackController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
        }
    }
}
