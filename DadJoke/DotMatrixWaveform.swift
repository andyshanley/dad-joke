import SwiftUI

/// A dot-matrix speech waveform, styled after Perplexity's voice-mode
/// indicator: a grid of small dots whose lit count per column follows a
/// wavy, multi-hump amplitude envelope (reading as speech syllables and
/// pauses rather than one smooth pulse), plus a per-dot flicker for texture.
/// This isn't driven by the actual audio signal -- it's a "something is
/// happening" indicator for the synthesis + playback window, same as the
/// reveal-concept mockup.
struct DotMatrixWaveform: View {
    var color: Color = .init(red: 0.906, green: 0.639, blue: 0.243) // matches app accent

    private let columns = 26
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
        let colGap = size.width / CGFloat(columns)
        let rowGap = (size.height / 2 - 3) / CGFloat(rowsPerSide)

        for i in 0..<columns {
            let x = Double(i) / Double(columns - 1)
            var envelope = sin(x * .pi * 4.2 + time * 2.1) * sin(x * .pi * 1.6 - time * 0.9 + 1.2)
            envelope = max(0.06, min(1, abs(envelope) * 1.15))

            let litRows = max(1, Int((envelope * Double(rowsPerSide)).rounded()))
            let cx = CGFloat(i) * colGap + colGap / 2

            for r in 0..<rowsPerSide {
                let lit = r < litRows
                let flicker = lit
                    ? (0.4 + 0.6 * abs(sin(Double(i) * 12.9 + Double(r) * 7.3 + time * 5)))
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
    DotMatrixWaveform()
        .frame(width: 210, height: 30)
        .padding()
        .background(Color.black)
}
