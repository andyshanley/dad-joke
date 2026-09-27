import Foundation

/// Runs the bundled Piper TTS runtime (a portable Python interpreter + the
/// piper-tts package) as a subprocess to synthesize natural-sounding British
/// speech, since AVSpeechSynthesizer's built-in voices sound robotic.
final class PiperSpeaker {
    static let shared = PiperSpeaker()

    private let pythonExecutable: URL
    private let speakScript: URL
    private let modelPath: URL
    private let configPath: URL
    private let cacheDir: URL

    private init() {
        let resources = Bundle.main.resourceURL!
        pythonExecutable = resources.appendingPathComponent("PythonRuntime/bin/python3.11")
        speakScript = resources.appendingPathComponent("speak.py")
        modelPath = resources.appendingPathComponent("PiperVoice/en_GB-alan-medium.onnx")
        configPath = resources.appendingPathComponent("PiperVoice/en_GB-alan-medium.onnx.json")

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = caches.appendingPathComponent("DadJoke", isDirectory: true)
    }

    /// Synthesizes `text` to a temporary WAV file and returns its URL, or nil on failure.
    func synthesize(text: String) async -> URL? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: self.runSynthesis(text: text))
            }
        }
    }

    private func runSynthesis(text: String) -> URL? {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        let process = Process()
        process.executableURL = pythonExecutable
        process.arguments = [
            speakScript.path,
            modelPath.path,
            configPath.path,
            outputURL.path,
            cacheDir.path,
        ]

        let stdin = Pipe()
        process.standardInput = stdin
        let stderr = Pipe()
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            print("Failed to launch Piper: \(error)")
            return nil
        }

        stdin.fileHandleForWriting.write(Data(text.utf8))
        try? stdin.fileHandleForWriting.close()

        process.waitUntilExit()

        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: outputURL.path)
        else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8) ?? "unknown error"
            print("Piper synthesis failed: \(errorText)")
            return nil
        }

        return outputURL
    }
}
