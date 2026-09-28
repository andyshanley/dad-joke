import SwiftUI
import AVFoundation

struct ContentView: View {
    /// Matches JokeDeckView's card-flip animation duration -- the waveform
    /// shouldn't appear until that settles, so it reads as "the flip lands,
    /// then the voice starts" rather than both happening at once.
    private static let cardFlipDuration = 0.5
    private static let waveformFadeDuration = 0.5
    private static let playbackRate: Float = 1.2

    @State private var currentJoke = ""
    @State private var lastJoke: String?
    @State private var hasDrawnBefore = false
    @State private var isSynthesizing = false
    @StateObject private var audioController = AudioPlaybackController()
    @State private var playbackMode: PlaybackMode = .textAndAudio
    @State private var showWaveform = false
    @State private var waveformDelayTask: Task<Void, Never>?
    @State private var isWindowFocused = true

    /// True from the moment synthesis starts until the audio finishes
    /// playing -- the disabled-tap guard should span that whole window,
    /// not just the synthesis half of it.
    private var isBusy: Bool { isSynthesizing || audioController.isPlaying }

    var body: some View {
        VStack(spacing: 22) {
            JokeDeckView(
                displayText: currentJoke,
                isPlaceholder: !hasDrawnBefore,
                isDisabled: isBusy,
                onTap: tellRandomJoke
            )

            ZStack {
                if showWaveform {
                    DotMatrixWaveform(
                        envelope: audioController.envelope,
                        progress: { audioController.progress }
                    )
                    .frame(width: 210, height: 30)
                    .transition(.opacity)
                } else if hasDrawnBefore && !isBusy {
                    Text("Tap for another")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .transition(.opacity)
                }
            }
            .frame(height: 30)
        }
        .padding(24)
        .frame(width: 300, height: 300)
        .overlay(alignment: .top) {
            PlaybackModeToggle(mode: $playbackMode)
                .padding(.top, 12)
        }
        .background(WindowConfigurator(isKeyWindow: $isWindowFocused))
        .containerBackground(for: .window) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular.tint(.black.opacity(isWindowFocused ? 0.3 : 0.1)), in: Rectangle())
        }
        .onChange(of: audioController.isPlaying) { _, playing in
            // The waveform needs real envelope data, which only exists once
            // playback actually starts (synthesis alone has no audio yet).
            // Synthesis always takes longer than the card flip, so gating
            // on isPlaying already satisfies "wait for the flip to finish"
            // in practice; the flip-duration delay below is just a floor.
            waveformDelayTask?.cancel()
            if playing {
                waveformDelayTask = Task {
                    try? await Task.sleep(for: .seconds(Self.cardFlipDuration))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeInOut(duration: Self.waveformFadeDuration)) {
                        showWaveform = true
                    }
                }
            } else {
                withAnimation(.easeInOut(duration: Self.waveformFadeDuration)) {
                    showWaveform = false
                }
            }
        }
    }

    private func tellRandomJoke() {
        guard let joke = randomJoke() else { return }
        lastJoke = joke
        hasDrawnBefore = true
        currentJoke = joke

        guard playbackMode == .textAndAudio else { return }
        isSynthesizing = true

        Task {
            let wavURL = await PiperSpeaker.shared.synthesize(text: joke)
            isSynthesizing = false

            guard let wavURL else { return }
            audioController.play(url: wavURL, rate: Self.playbackRate)
        }
    }

    private func randomJoke() -> String? {
        guard dadJokes.count > 1 else { return dadJokes.first }
        var joke: String
        repeat {
            joke = dadJokes.randomElement()!
        } while joke == lastJoke
        return joke
    }
}

#Preview {
    ContentView()
}
