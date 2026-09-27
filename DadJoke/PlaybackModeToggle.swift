import SwiftUI

enum PlaybackMode {
    case textOnly
    case textAndAudio
}

/// A two-option glass segmented toggle, styled after the system's icon-only
/// segmented controls (e.g. Xcode's inspector toggle): a rounded glass pill
/// with a highlighted capsule behind the selected option.
struct PlaybackModeToggle: View {
    @Binding var mode: PlaybackMode

    var body: some View {
        HStack(spacing: 2) {
            option(systemName: "text.bubble", isSelected: mode == .textOnly) {
                mode = .textOnly
            }
            option(systemName: "speaker.wave.2.fill", isSelected: mode == .textAndAudio) {
                mode = .textAndAudio
            }
        }
        .padding(3)
        .glassEffect(.regular, in: Capsule())
    }

    private func option(systemName: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 26, height: 20)
                .background {
                    if isSelected {
                        Capsule().fill(.white.opacity(0.32))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
