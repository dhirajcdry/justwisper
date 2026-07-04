import AppKit
import ApplicationServices

/// Inserts text into the target app with a layered strategy (most reliable first):
///   1. Re-activate the app that had focus.
///   2. Accessibility: set the focused element's selected text (insert at cursor).
///   3. Fallback: clipboard + synthesized ⌘V, restoring the previous clipboard.
/// All paths require Accessibility permission.
enum TextInjector {
    @discardableResult
    static func insert(_ text: String, into app: NSRunningApplication?) -> Bool {
        guard !text.isEmpty else { return true }
        guard AXIsProcessTrusted() else { return false }

        // Bring the target app forward so insertion lands in its focused field.
        if let app, !app.isActive {
            app.activate(options: [.activateAllWindows])
            usleep(60_000) // let activation settle
        }

        if insertViaAccessibility(text) { return true }

        pasteViaCommandV(text)
        return true
    }

    /// Insert at the caret by setting the focused element's selected text.
    private static func insertViaAccessibility(_ text: String) -> Bool {
        let system = AXUIElementCreateSystemWide()
        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let ref = focusedRef,
              CFGetTypeID(ref) == AXUIElementGetTypeID()
        else { return false }

        let element = unsafeBitCast(ref, to: AXUIElement.self)

        // Only attempt if the element actually supports settable selected text.
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        guard settable.boolValue else { return false }

        let result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        return result == .success
    }

    private static func pasteViaCommandV(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previous = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            postCommandV()
            if let previous {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    pasteboard.clearContents()
                    pasteboard.setString(previous, forType: .string)
                }
            }
        }
    }

    private static func postCommandV() {
        postKeyCombo(virtualKey: 9, flags: .maskCommand)   // V
    }

    /// Synthesize ⌘+<key> (modifier down, key down/up, modifier up).
    private static func postKeyCombo(virtualKey: CGKeyCode, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)
        let cmdKey: CGKeyCode = 55
        let tap: CGEventTapLocation = .cghidEventTap

        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: true)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: false)
        keyUp?.flags = flags
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: cmdKey, keyDown: false)

        cmdDown?.post(tap: tap)
        keyDown?.post(tap: tap)
        keyUp?.post(tap: tap)
        cmdUp?.post(tap: tap)
    }
}
