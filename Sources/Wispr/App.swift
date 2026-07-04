import SwiftUI

@main
struct WisprApp: App {
    @StateObject private var model = AppModel()

    init() {
        FontLoader.register()
    }

    var body: some Scene {
        Window("justwisper", id: "main") {
            ContentView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            Text(model.statusText)          // live status, always visible at a glance
            if case .error = model.state {
                Button("Retry model load") { model.retryModelLoad() }
            }
            Divider()
            Button("Show justwisper") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
            Divider()
            Button("Quit justwisper") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(nsImage: model.statusIcon)
        }
    }
}
