import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var currentJoke = "Press the button for a dad joke!"
    @State private var isSpeaking = false
    @State private var audioPlayer: AVAudioPlayer?

    var body: some View {
        VStack(spacing: 20) {
            Text(currentJoke)
                .font(.body)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button("Random Dad Joke") {
                tellRandomJoke()
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(isSpeaking)
        }
        .padding(24)
        .frame(width: 300, height: 300)
    }

    private func tellRandomJoke() {
        guard let joke = dadJokes.randomElement() else { return }
        currentJoke = joke
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
}

#Preview {
    ContentView()
}
