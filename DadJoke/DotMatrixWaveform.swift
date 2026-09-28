import SwiftUI

/// A dot-matrix speech waveform, styled after Perplexity's voice-mode
/// indicator: a grid of small dots whose lit count per column reflects the
/// clip's real amplitude at that point (computed once from the audio file
/// itself), with a per-dot flicker for texture. Columns already passed by
/// playback position render at full brightness; columns not yet reached
/// are dimmed, so the shape doubles as a progress indicator.
struct DotMatrixWaveform: View {
    var envelope: [Float]
    var progress: () -> Double
    var color: Color = .init(red: 0.906, green: 0.639, blue: 0.243) // matches app accent

    private let rowsPerSide = 4
    private let dotRadius: CGFloat = 1.3

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { graphicsContext, size in
                draw(in: &graphicsContext, size: size, time: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private func draw(in ctx: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        guard !envelope.isEmpty else { return }
        let columns = envelope.count
        let colGap = size.width / CGFloat(columns)
        let rowGap = (size.height / 2 - 3) / CGFloat(rowsPerSide)
        let currentProgress = progress()

        for i in 0..<columns {
            let amplitude = Double(envelope[i])
            let litRows = max(1, Int((amplitude * Double(rowsPerSide)).rounded()))
            let cx = CGFloat(i) * colGap + colGap / 2

            let columnPosition = Double(i) / Double(max(columns - 1, 1))
            let alreadyPlayed = columnPosition <= currentProgress

            for r in 0..<rowsPerSide {
                let lit = r < litRows
                let baseBrightness = alreadyPlayed ? 1.0 : 0.32
                let flicker = lit
                    ? baseBrightness * (0.55 + 0.45 * abs(sin(Double(i) * 12.9 + Double(r) * 7.3 + time * 5)))
                    : 0.07

                let cyTop = size.height / 2 - (CGFloat(r) + 0.5) * rowGap
                let cyBot = size.height / 2 + (CGFloat(r) + 0.5) * rowGap

                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - dotRadius, y: cyTop - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
                    with: .color(color.opacity(flicker))
                )
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx - dotRadius, y: cyBot - dotRadius, width: dotRadius * 2, height: dotRadius * 2)),
                    with: .color(color.opacity(flicker))
                )
            }
        }
    }
}

#Preview {
    DotMatrixWaveform(
        envelope: (0..<26).map { i in Float(abs(sin(Double(i) * 0.4))) },
        progress: { 0.4 }
    )
    .frame(width: 210, height: 30)
    .padding()
    .background(Color.black)
}
