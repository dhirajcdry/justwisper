import AppKit
import ApplicationServices

/// Confirmed AX insertion and an unverified synthetic paste are distinct results.
/// All mutations stay on the main actor; only one insertion owns the clipboard.
@MainActor
enum TextInjector {
    enum Result {
        case inserted
        case pasteRequested
        case failed(String)
    }

    private static var busy = false

    static func insert(_ text: String, into app: NSRunningApplication?) async -> Result {
        guard !text.isEmpty else { return .failed("There is no text to insert.") }
        guard !Task.isCancelled else { return .failed("Insertion cancelled.") }
        guard AXIsProcessTrusted() else { return .failed("Enable Accessibility to insert text into other apps.") }
        guard let app, !app.isTerminated,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return .failed("The original destination app is unavailable. Copy your transcript from History.")
        }
        guard !busy else { return .failed("Another insertion is finishing. Try again in a moment.") }
        busy = true
        defer { busy = false }

        if !app.isActive {
            guard app.activate(options: [.activateAllWindows]) else {
                return .failed("Could not activate the original destination app.")
            }
            do { try await Task.sleep(for: .milliseconds(80)) }
            catch { return .failed("Insertion cancelled.") }
        }
        guard !Task.isCancelled, isFrontmost(app) else {
            return .failed("The focused app changed. Copy your transcript from History.")
        }
        if insertViaAccessibility(text, targetPID: app.processIdentifier) { return .inserted }

        // Allocate every event before changing the clipboard. No deferred closure
        // may send a paste into a different app after this method has returned.
        guard let source = CGEventSource(stateID: .hidSystemState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false) else {
            return .failed("Could not create the paste shortcut.")
        }
        guard let clipboard = ClipboardTransaction.begin(text: text, on: .general) else {
            return .failed("Could not safely prepare the clipboard. Copy your transcript from History.")
        }
        defer { clipboard.restoreIfUnchanged() }
        do { try await Task.sleep(for: .milliseconds(50)) }
        catch { return .failed("Insertion cancelled.") }
        guard !Task.isCancelled, isFrontmost(app), clipboard.stillOwnsClipboard else {
            return .failed("The app or clipboard changed before paste. Your transcript is in History.")
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        commandDown.post(tap: .cghidEventTap)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)
        // Allow the destination to read the clipboard; keep our insertion lock
        // until restoration. A new user copy always wins over our old snapshot.
        try? await Task.sleep(for: .milliseconds(600))
        return .pasteRequested
    }

    private static func isFrontmost(_ app: NSRunningApplication) -> Bool {
        !app.isTerminated && NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
    }

    private static func insertViaAccessibility(_ text: String, targetPID: pid_t) -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return false }
        let element = unsafeBitCast(focused, to: AXUIElement.self)
        var focusedPID: pid_t = 0
        guard AXUIElementGetPid(element, &focusedPID) == .success, focusedPID == targetPID else { return false }
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable) == .success,
              settable.boolValue else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success
    }
}
