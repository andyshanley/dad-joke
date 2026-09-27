import SwiftUI

@main
struct DadJokeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 300, height: 300)
        .windowStyle(.hiddenTitleBar)
    }
}
