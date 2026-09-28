import AVFoundation
import Accelerate

/// Plays a synthesized joke and reports whether it's actually still
/// audible. AVAudioPlayer has no publisher for playback finishing, so this
/// uses the delegate callback -- checking `player.isPlaying` right after
/// calling `play()` is not reliable enough for driving UI (that flag can
/// still read true for a moment after the audio has already ended).
final class AudioPlaybackController: NSObject, ObservableObject {
    static let envelopeBucketCount = 26

    @Published private(set) var isPlaying = false
    /// Per-bucket RMS amplitude across the whole clip, normalized to its own
    /// peak (0...1). Computed once up front from the WAV file itself, since
    /// the whole file already exists on disk before playback starts -- no
    /// real-time analysis needed.
    @Published private(set) var envelope: [Float] = []

    private var player: AVAudioPlayer?

    /// `rate` is a playback-speed multiplier (1.2 = 20% faster), applied
    /// after synthesis rather than by retuning Piper, since it only needs
    /// to affect what the user hears, not the synthesis pipeline itself.
    func play(url: URL, rate: Float = 1.0) {
        envelope = Self.computeEnvelope(url: url, bucketCount: Self.envelopeBucketCount)

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

    /// Fraction (0...1) through the clip's own timeline. This tracks audio
    /// content position, not wall-clock time, so it still reaches 1.0
    /// exactly at the end regardless of playback rate. Read directly rather
    /// than published, since the waveform view polls it every frame and
    /// publishing it would trigger a full view re-render each time.
    var progress: Double {
        guard let player, player.duration > 0 else { return 0 }
        return min(1, max(0, player.currentTime / player.duration))
    }

    private static func computeEnvelope(url: URL, bucketCount: Int) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }

        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount),
              (try? file.read(into: buffer)) != nil,
              let channelData = buffer.floatChannelData
        else { return [] }

        let samples = channelData[0]
        let totalSamples = Int(buffer.frameLength)
        guard totalSamples > 0 else { return [] }

        let bucketSize = max(1, totalSamples / bucketCount)
        var envelope: [Float] = []
        envelope.reserveCapacity(bucketCount)

        for i in 0..<bucketCount {
            let start = i * bucketSize
            let length = (i == bucketCount - 1) ? (totalSamples - start) : bucketSize
            guard length > 0, start < totalSamples else {
                envelope.append(0)
                continue
            }
            var rms: Float = 0
            vDSP_rmsqv(samples + start, 1, &rms, vDSP_Length(length))
            envelope.append(rms)
        }

        let peak = envelope.max() ?? 0
        guard peak > 0 else { return envelope }
        return envelope.map { $0 / peak }
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
