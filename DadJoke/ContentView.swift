import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var currentJoke = ""
    @State private var lastJoke: String?
    @State private var hasDrawnBefore = false
    @State private var isSpeaking = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var playbackMode: PlaybackMode = .textAndAudio

    var body: some View {
        VStack(spacing: 22) {
            JokeDeckView(
                displayText: currentJoke,
                isPlaceholder: !hasDrawnBefore,
                isDisabled: isSpeaking,
                onTap: tellRandomJoke
            )

            ZStack {
                if isSpeaking {
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
            Rectangle().glassEffect(.regular, in: Rectangle())
        }
    }

    private func tellRandomJoke() {
        guard let joke = randomJoke() else { return }
        lastJoke = joke
        hasDrawnBefore = true
        currentJoke = joke

        guard playbackMode == .textAndAudio else { return }
        isSpeaking = true

        Task {
            let wavURL = await PiperSpeaker.shared.synthesize(text: joke)
            isSpeaking = false

            guard let wavURL else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: wavURL)
                audioPlayer = player
                player.play()
            } catch {
                print("Failed to play synthesized audio: \(error)")
            }
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
