import AppKit

/// Triggers dictation from the Right Option key (keyCode 61) three ways — like Wispr Flow:
///   • Hold        → push-to-talk: records while held, stops on release.
///   • Quick tap    → a brief take that stops on its own after the double-tap window.
///   • Double-tap  → hands-free:   latches recording on; a single tap stops it.
///
/// Uses a global flagsChanged monitor so it works in any app (requires Accessibility).
///
/// Everything is an explicit `Phase` so the three gestures can't be confused for
/// one another — the old boolean soup let a plain "tap to stop" be misread as the
/// second half of a double-tap (a stray timestamp), which made stopping erratic.
final class HotkeyMonitor {
    var onStart: () -> Void = {}
    var onStop: () -> Void = {}
    /// Fires when the hands-free latch turns on/off, so the UI can reflect it.
    var onHandsFreeChange: (Bool) -> Void = { _ in }
    /// Fires on Esc — cancel/dismiss the current dictation. No-op if idle.
    var onCancel: () -> Void = {}

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var escGlobalMonitor: Any?
    private var escLocalMonitor: Any?
    private let escKeyCode: UInt16 = 53

    /// The recorder's gesture state. Only these five states exist; every event
    /// is interpreted against the current one, so gestures can't blur together.
    private enum Phase {
        case idle        // not recording
        case holding     // first press is down; keyUp decides hold-vs-tap
        case tapPending  // released one quick tap; waiting for a possible 2nd tap
        case secondDown  // second press is down (completing a double-tap)
        case latched     // hands-free on; a single tap stops
    }
    private var phase: Phase = .idle
    private var downTime = Date()
    private var consumeNextUp = false     // swallow the release that goes with a stop-tap
    private var pendingStop: DispatchWorkItem?

    /// keyCode 61 == Right Option. (Left Option is 58.)
    private let keyCode: UInt16 = 61
    private let holdThreshold: TimeInterval = 0.3   // held longer than this = push-to-talk
    private let doubleTapGap: TimeInterval = 0.4    // max gap between taps for a double-tap

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
        }
        // Local monitor so it also works while one of our own windows is key.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handle(event)
            return event
        }

        // Esc cancels the current dictation from anywhere (global) or from our
        // own windows (local). onCancel is a no-op when nothing is recording,
        // so we don't swallow Esc for other purposes.
        escGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == self.escKeyCode else { return }
            DispatchQueue.main.async { self.onCancel() }
        }
        escLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let self, event.keyCode == self.escKeyCode {
                DispatchQueue.main.async { self.onCancel() }
            }
            return event
        }
    }

    /// Clear all state — call when recording is stopped elsewhere (flow-bar ✓/✕,
    /// Esc, errors) so the key stays in sync with reality.
    func reset() {
        cancelPendingStop()
        phase = .idle
        consumeNextUp = false
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == keyCode else { return }
        if event.modifierFlags.contains(.option) { keyDown() } else { keyUp() }
    }

    private func keyDown() {
        downTime = Date()

        switch phase {
        case .latched:
            // Hands-free is on → a tap stops it. Swallow the matching release.
            cancelPendingStop()
            phase = .idle
            consumeNextUp = true
            emitHandsFree(false)
            fire(onStop)

        case .tapPending:
            // A second press arrived inside the window → this is a double-tap in
            // progress. Keep the take rolling; keyUp decides latch-vs-hold.
            cancelPendingStop()
            phase = .secondDown

        case .idle:
            // Fresh press → begin recording (covers both a hold and a first tap).
            phase = .holding
            fire(onStart)

        case .holding, .secondDown:
            // A key repeat / duplicate down (both monitors, or OS repeat). Ignore.
            break
        }
    }

    private func keyUp() {
        if consumeNextUp { consumeNextUp = false; return }

        let held = Date().timeIntervalSince(downTime)

        switch phase {
        case .holding:
            if held >= holdThreshold {
                // Deliberate hold → push-to-talk end.
                phase = .idle
                fire(onStop)
            } else {
                // First quick tap: keep recording through the double-tap window,
                // then finalize as a brief take if no second tap arrives.
                phase = .tapPending
                scheduleFinalize()
            }

        case .secondDown:
            if held >= holdThreshold {
                // Tap-then-hold → treat the hold as push-to-talk; release stops.
                phase = .idle
                fire(onStop)
            } else {
                // Two quick taps → latch hands-free on.
                phase = .latched
                emitHandsFree(true)
            }

        case .idle, .tapPending, .latched:
            // A release with no matching press we care about — ignore.
            break
        }
    }

    /// If no second tap lands within the window, the lone quick tap finalizes as
    /// a short push-to-talk take.
    private func scheduleFinalize() {
        cancelPendingStop()
        let work = DispatchWorkItem { [weak self] in
            guard let self, case .tapPending = self.phase else { return }
            self.phase = .idle
            self.onStop()
        }
        pendingStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + doubleTapGap, execute: work)
    }

    private func cancelPendingStop() {
        pendingStop?.cancel()
        pendingStop = nil
    }

    private func fire(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }

    private func emitHandsFree(_ on: Bool) {
        DispatchQueue.main.async { [weak self] in self?.onHandsFreeChange(on) }
    }
}
