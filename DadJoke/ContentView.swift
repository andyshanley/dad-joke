import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var currentJoke = ""
    @State private var lastJoke: String?
    @State private var hasDrawnBefore = false
    @State private var isSynthesizing = false
    @StateObject private var audioController = AudioPlaybackController()
    @State private var playbackMode: PlaybackMode = .textAndAudio

    /// True from the moment synthesis starts until the audio finishes
    /// playing -- the waveform (and the disabled-tap guard) should span
    /// that whole window, not just the synthesis half of it.
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
                if isBusy {
                    DotMatrixWaveform()
                        .frame(width: 210, height: 30)
                } else if hasDrawnBefore {
                    Text("Tap for another")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
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
        .background(WindowConfigurator())
        .containerBackground(for: .window) {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular.tint(.black.opacity(0.55)), in: Rectangle())
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
            audioController.play(url: wavURL, rate: 1.1)
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
