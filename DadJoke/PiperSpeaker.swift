import Foundation

/// Runs the bundled Piper TTS runtime (a portable Python interpreter + the
/// piper-tts package) as a subprocess to synthesize natural-sounding British
/// speech, since AVSpeechSynthesizer's built-in voices sound robotic.
///
/// To make jokes actually sound like they're being *told* rather than just
/// read aloud, each joke is split into a setup and a punchline (where
/// possible) and synthesized as two segments with different delivery
/// parameters, separated by a short comedic-timing pause.
final class PiperSpeaker {
    static let shared = PiperSpeaker()

    /// Piper's default is noise_scale=0.667, noise_w_scale=0.8, length_scale=1.0.
    /// Setup: mild liveliness bump, slightly unhurried to build anticipation.
    private static let setupParams = SynthesisSegment.Params(
        lengthScale: 1.05, noiseScale: 0.75, noiseWScale: 0.85
    )
    /// Punchline: snappier pace and more vocal energy, like landing a joke.
    private static let punchlineParams = SynthesisSegment.Params(
        lengthScale: 0.92, noiseScale: 0.9, noiseWScale: 0.9
    )
    private static let comedicPauseMilliseconds = 350

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

        let payload = Self.synthesisPayload(for: text)
        guard let jsonData = try? JSONEncoder().encode(payload) else { return nil }
        stdin.fileHandleForWriting.write(jsonData)
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

    private static func synthesisPayload(for text: String) -> SynthesisPayload {
        let (setup, punchline) = splitSetupAndPunchline(text)

        var segments: [SynthesisSegment] = []
        if let setup {
            segments.append(SynthesisSegment(text: setup, params: setupParams))
        }
        segments.append(SynthesisSegment(text: punchline, params: punchlineParams))

        return SynthesisPayload(
            segments: segments,
            pauseMilliseconds: segments.count > 1 ? comedicPauseMilliseconds : 0
        )
    }

    /// Splits a joke into a setup and punchline for comedic-timing delivery.
    /// Falls back to treating the whole joke as the punchline when no clean
    /// split point is found (e.g. short one-liners).
    private static func splitSetupAndPunchline(_ text: String) -> (setup: String?, punchline: String) {
        let sentences = splitIntoSentences(text)
        if sentences.count >= 2 {
            let punchline = sentences.last!
            let setup = sentences.dropLast().joined(separator: " ")
            return (setup, punchline)
        }

        if let commaRange = text.range(of: ",", options: .backwards) {
            let setup = String(text[text.startIndex..<commaRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
            let punchline = String(text[commaRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)
            if setup.count >= 8, punchline.count >= 8 {
                return (setup, punchline)
            }
        }

        return (nil, text)
    }

    private static func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        var current = ""
        let terminators: Set<Character> = [".", "?", "!"]

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            current.append(character)

            if terminators.contains(character) {
                let next = text.index(after: index)
                if next == text.endIndex || text[next] == " " {
                    let trimmed = current.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        sentences.append(trimmed)
                    }
                    current = ""
                }
            }
            index = text.index(after: index)
        }

        let remainder = current.trimmingCharacters(in: .whitespaces)
        if !remainder.isEmpty {
            sentences.append(remainder)
        }

        return sentences
    }
}

private struct SynthesisSegment: Encodable {
    struct Params {
        let lengthScale: Double
        let noiseScale: Double
        let noiseWScale: Double
    }

    let text: String
    let params: Params

    enum CodingKeys: String, CodingKey {
        case text
        case lengthScale = "length_scale"
        case noiseScale = "noise_scale"
        case noiseWScale = "noise_w_scale"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(params.lengthScale, forKey: .lengthScale)
        try container.encode(params.noiseScale, forKey: .noiseScale)
        try container.encode(params.noiseWScale, forKey: .noiseWScale)
    }
}

private struct SynthesisPayload: Encodable {
    let segments: [SynthesisSegment]
    let pauseMilliseconds: Int

    enum CodingKeys: String, CodingKey {
        case segments
        case pauseMilliseconds = "pause_ms"
    }
}
