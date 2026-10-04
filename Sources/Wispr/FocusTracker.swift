import AppKit

/// Remembers the most recent app that ISN'T Wispr, so we can re-activate it and
/// paste the transcript into its focused text field — the way Wispr Flow does.
@MainActor
final class FocusTracker {
    private(set) var lastExternalApp: NSRunningApplication?
    private var observer: NSObjectProtocol?

    func start() {
        if let front = NSWorkspace.shared.frontmostApplication, !isSelf(front) {
            lastExternalApp = front
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            // NotificationCenter delivers this observer on OperationQueue.main.
            MainActor.assumeIsolated {
                guard let self else { return }
                if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                   !self.isSelf(app) {
                    self.lastExternalApp = app
                }
            }
        }
    }

    private func isSelf(_ app: NSRunningApplication) -> Bool {
        app.processIdentifier == NSRunningApplication.current.processIdentifier
    }
}
