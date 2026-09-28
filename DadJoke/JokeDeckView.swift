import SwiftUI

/// Rotates a view onto/off its edge for a card-flip content swap. Applied as
/// an asymmetric transition: content rotates to the edge and disappears on
/// the way out, and appears from the edge rotating to flat on the way in.
private struct CardFlipModifier: ViewModifier {
    let angle: Double

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0))
            .opacity(angle == 0 ? 1 : 0)
    }
}

private extension AnyTransition {
    static var cardFlip: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: CardFlipModifier(angle: -90), identity: CardFlipModifier(angle: 0)),
            removal: .modifier(active: CardFlipModifier(angle: 90), identity: CardFlipModifier(angle: 0))
        )
    }
}

/// A fanned stack of cards you draw a joke from, instead of a button that
/// swaps a text label. The top card starts face-down; each tap flips it to
/// reveal a new joke, borrowed from Google Arts & Culture's "tap the top
/// card to reveal it" and Deepstash's obscure-then-reveal pattern.
struct JokeDeckView: View {
    let displayText: String
    let isPlaceholder: Bool
    let isDisabled: Bool
    let onTap: () -> Void

    private let cardSize = CGSize(width: 176, height: 132)

    var body: some View {
        ZStack {
            shadowCard.rotationEffect(.degrees(6)).offset(y: 5).opacity(0.35)
            shadowCard.rotationEffect(.degrees(-7)).offset(y: 3).opacity(0.5)

            cardFace
                .id(displayText)
                .transition(.cardFlip)
        }
        .animation(.easeInOut(duration: 0.5), value: displayText)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDisabled else { return }
            onTap()
        }
    }

    private var shadowCard: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.white.opacity(0.07))
            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
            .frame(width: cardSize.width, height: cardSize.height)
    }

    private var cardFace: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.white.opacity(isPlaceholder ? 0.09 : 0.16))
            .strokeBorder(.white.opacity(0.14), lineWidth: 1)
            .frame(width: cardSize.width, height: cardSize.height)
            .overlay {
                if isPlaceholder {
                    VStack(spacing: 8) {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("Tap to draw a joke")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(displayText)
                        .font(.system(size: 13))
                        .minimumScaleFactor(0.45)
                        .lineLimit(6)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(12)
                }
            }
    }
}

#Preview {
    JokeDeckView(
        displayText: "Why did the scarecrow win an award? Because he was outstanding in his field.",
        isPlaceholder: false,
        isDisabled: false,
        onTap: {}
    )
    .padding(60)
    .background(Color(red: 0.17, green: 0.17, blue: 0.19))
}
