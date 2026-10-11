import SwiftUI

@main
struct WisprApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
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
            Button("Show justwisper") { MainWindow.show() }
            Divider()
            Button("Quit justwisper") { NSApplication.shared.terminate(nil) }
        } label: {
            StatusLabel(icon: model.statusIcon)
        }
    }
}

/// Brings the main window to the user, wherever they are. The window is moved
/// to the *current* desktop rather than leaving the app "activated" on another
/// Space — with macOS's "switch to a Space with open windows" turned off, that
/// looked like clicking the app did nothing.
@MainActor
enum MainWindow {
    /// Reopens the window after it was closed (SwiftUI's `openWindow`, captured
    /// from the always-present menu bar label).
    static var reopen: (() -> Void)?

    static var window: NSWindow? {
        NSApp.windows.first { w in
            !(w is NSPanel) && (w.identifier?.rawValue.hasPrefix("main") == true || w.title == "justwisper")
        }
    }

    /// Follow the user across desktops instead of pinning to the one it opened on.
    static func adoptActiveSpace() {
        window?.collectionBehavior.insert(.moveToActiveSpace)
    }

    static func show() {
        if let w = window {
            adoptActiveSpace()
            if w.isMiniaturized { w.deminiaturize(nil) }
            w.makeKeyAndOrderFront(nil)
        } else {
            reopen?()
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Dock icon / Finder / Spotlight on the running app: always show the window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainActor.assumeIsolated { MainWindow.show() }
        return false
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        MainActor.assumeIsolated { MainWindow.adoptActiveSpace() }
    }
}

/// Menu bar icon. Also hands `openWindow` to `MainWindow` so the window can be
/// recreated after it's been closed.
private struct StatusLabel: View {
    let icon: NSImage
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Image(nsImage: icon)
            .onAppear { MainWindow.reopen = { openWindow(id: "main") } }
    }
}
