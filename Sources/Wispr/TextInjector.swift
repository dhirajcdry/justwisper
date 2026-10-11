import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// Delivers text the way Wispr Flow does: through the clipboard and a ⌘V,
/// everywhere. Writing AX `selectedText` directly looked cleaner but failed
/// silently in web editors (ChatGPT in Dia, Discord, Slack — Chromium accepts
/// the write and the page's editor discards it), while a paste goes through the
/// page's own paste handling. The clipboard is a lazy promise, so we know
/// whether the app actually read it: that's what "landed" means now.
/// All mutations stay on the main actor; only one insertion owns the clipboard.
@MainActor
enum TextInjector {
    enum Result {
        case inserted
        case pasteRequested
        case failed(String)
    }

    private static var busy = false
    /// The previous paste's deferred clipboard restore, if it hasn't run yet.
    private static var pendingRestore: Task<Void, Never>?

    /// How long an app gets to read the clipboard after ⌘V. Generous: a busy
    /// Electron renderer can take most of a second; a real failure just waits.
    static let readTimeout: Duration = .milliseconds(2000)
    /// Keep the transcript on the clipboard briefly after it was read — some
    /// apps read twice (a type probe, then the data).
    static let restoreDelay: Duration = .milliseconds(500)

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
        // Finish the last paste's restore first, so this transaction snapshots
        // the user's real clipboard rather than our previous transcript.
        if let restore = pendingRestore {
            restore.cancel()
            await restore.value
            pendingRestore = nil
        }

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
        // A password field (or an app holding Secure Keyboard Entry) swallows
        // synthetic keystrokes — say so instead of failing silently.
        if IsSecureEventInputEnabled() {
            return .failed("Secure input is on (a password field or Secure Keyboard Entry), so pasting is blocked. Your transcript is in History.")
        }
        // A modifier still held (the Right Option hotkey, Shift…) would turn
        // ⌘V into ⌥⌘V and the app would ignore it. Give the fingers a moment.
        await waitForModifiersReleased(upTo: .milliseconds(400))

        // Allocate every event before changing the clipboard. No deferred closure
        // may send a paste into a different app after this method has returned.
        let vKey = keyCodeForV()
        guard let source = CGEventSource(stateID: .hidSystemState),
              let commandDown = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: true),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false),
              let commandUp = CGEvent(keyboardEventSource: source, virtualKey: 55, keyDown: false) else {
            return .failed("Could not create the paste shortcut.")
        }
        guard let clipboard = ClipboardTransaction.begin(text: text, on: .general) else {
            return .failed("Could not safely prepare the clipboard. Copy your transcript from History.")
        }
        do { try await Task.sleep(for: .milliseconds(30)) }
        catch { clipboard.restoreIfUnchanged(); return .failed("Insertion cancelled.") }
        guard !Task.isCancelled, isFrontmost(app), clipboard.stillOwnsClipboard else {
            clipboard.restoreIfUnchanged()
            return .failed("The app or clipboard changed before paste. Your transcript is in History.")
        }
        // A real ⌘V: Command flagged on every event, with a beat between them.
        // Posted synchronously so Command can never be left held down.
        commandDown.flags = .maskCommand
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        for event in [commandDown, keyDown, keyUp, commandUp] {
            event.post(tap: .cghidEventTap)
            usleep(8_000)
        }

        // Only an app reading our clipboard proves the paste happened.
        guard await clipboard.waitUntilRead(timeout: readTimeout) else {
            // Nobody took it — there was no text field focused, or the app
            // ignored ⌘V. Leave the transcript on the clipboard for a manual paste.
            clipboard.keepTranscript()
            let name = app.localizedName ?? "the app"
            return .failed("Didn't land in \(name) — click into a text field and press ⌘V. It's on your clipboard.")
        }
        // Restore in the background; a new insertion or any newer copy by the
        // user ends the wait early (a newer copy always wins).
        pendingRestore = Task {
            try? await Task.sleep(for: restoreDelay)
            clipboard.restoreIfUnchanged()
        }
        return .inserted
    }

    private static func isFrontmost(_ app: NSRunningApplication) -> Bool {
        !app.isTerminated && NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier
    }

    private static func waitForModifiersReleased(upTo limit: Duration) async {
        let held: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let deadline = ContinuousClock.now + limit
        while !CGEventSource.flagsState(.hidSystemState).intersection(held).isEmpty,
              ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    /// The key that types "v" in the current layout (Dvorak, AZERTY…), so ⌘V
    /// means Paste everywhere. Translated with ⌘ held, so "Dvorak – QWERTY ⌘"
    /// layouts resolve to their QWERTY shortcut key. Falls back to the ANSI V key.
    private static func keyCodeForV() -> CGKeyCode {
        let fallback = CGKeyCode(kVK_ANSI_V)
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return fallback
        }
        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> CGKeyCode in
            guard let layout = buffer.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else {
                return fallback
            }
            for code in 0..<128 {
                var deadKeys: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(layout, UInt16(code), UInt16(kUCKeyActionDisplay), UInt32((cmdKey >> 8) & 0xFF),
                                            UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                            &deadKeys, chars.count, &length, &chars)
                if status == noErr, length == 1, chars[0] == UniChar(("v" as Unicode.Scalar).value) {
                    return CGKeyCode(code)
                }
            }
            return fallback
        }
    }
}
