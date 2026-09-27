import SwiftUI

enum PlaybackMode {
    case textOnly
    case textAndAudio
}

/// A glass segmented toggle sized and styled after Finder's toolbar view-mode
/// picker: a large rounded glass pill with a neutral (non-accent-colored)
/// highlight behind the selected option.
struct PlaybackModeToggle: View {
    @Binding var mode: PlaybackMode

    var body: some View {
        HStack(spacing: 2) {
            option(systemName: "speaker.slash", isSelected: mode == .textOnly) {
                mode = .textOnly
            }
            option(systemName: "speaker.wave.2.fill", isSelected: mode == .textAndAudio) {
                mode = .textAndAudio
            }
        }
        .padding(4)
        .glassEffect(.regular, in: Capsule())
    }

    private func option(systemName: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 34, height: 26)
                .background {
                    if isSelected {
                        Capsule().fill(.white.opacity(0.3))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
