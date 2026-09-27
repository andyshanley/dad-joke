import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var currentJoke = "Press the button for a dad joke!"
    @State private var speechSynthesizer = AVSpeechSynthesizer()

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
        }
        .padding(24)
        .frame(width: 300, height: 300)
    }

    private func tellRandomJoke() {
        guard let joke = dadJokes.randomElement() else { return }
        currentJoke = joke

        let utterance = AVSpeechUtterance(string: joke)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        speechSynthesizer.stopSpeaking(at: .immediate)
        speechSynthesizer.speak(utterance)
    }
}

#Preview {
    ContentView()
}
