import SwiftUI
import AppKit

/// Makes the title bar blend seamlessly into the window's content: no keyline
/// separator, and content draws underneath the title bar area instead of
/// stopping below it. Also reports whether the window is currently key, so
/// the glass background can dim when the app isn't focused.
struct WindowConfigurator: NSViewRepresentable {
    @Binding var isKeyWindow: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(nsView.window, coordinator: context.coordinator)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isKeyWindow: $isKeyWindow)
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.isOpaque = false
        window.backgroundColor = .clear

        coordinator.observe(window)
    }

    final class Coordinator {
        private let isKeyWindow: Binding<Bool>
        private weak var observedWindow: NSWindow?
        private var tokens: [NSObjectProtocol] = []

        init(isKeyWindow: Binding<Bool>) {
            self.isKeyWindow = isKeyWindow
        }

        func observe(_ window: NSWindow) {
            guard observedWindow !== window else { return }
            let center = NotificationCenter.default
            tokens.forEach(center.removeObserver)
            tokens.removeAll()
            observedWindow = window

            isKeyWindow.wrappedValue = window.isKeyWindow

            tokens.append(center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [isKeyWindow] _ in
                isKeyWindow.wrappedValue = true
            })
            tokens.append(center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [isKeyWindow] _ in
                isKeyWindow.wrappedValue = false
            })
        }

        deinit {
            let center = NotificationCenter.default
            tokens.forEach(center.removeObserver)
        }
    }
}
