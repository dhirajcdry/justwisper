import SwiftUI
import AppKit

/// Manages the floating "Flow Bar" — a borderless, always-on-top panel pinned to
/// the bottom-center of the active screen that appears while dictating.
///
/// Visibility is driven purely by `AppModel.state` (see `syncOverlay`), and
/// show/hide are made race-safe with a token so a stale hide animation can never
/// order the panel out after a newer show — the bug that made the bar vanish (or
/// never appear) when dictations came back-to-back.
@MainActor
final class OverlayController {
    private var panel: NSPanel?
    private weak var model: AppModel?
    private var visible = false
    private var hideToken = 0

    // User-chosen position (drag the bar). Persisted so it survives relaunches;
    // nil means "use the default bottom-center".
    private let defaults = UserDefaults.standard
    private let originXKey = "overlayOriginX"
    private let originYKey = "overlayOriginY"
    private var isDragging = false
    private var lastDragMouse: NSPoint?

    func configure(model: AppModel) {
        self.model = model
    }

    // MARK: - Dragging

    /// Follow the pointer using absolute *screen* coordinates. Measuring against
    /// the bar's own moving coordinate space caused a feedback loop (the bar
    /// moves → the next reading shifts → jitter). Screen space is fixed, so the
    /// grab point stays glued to the cursor.
    func dragStep() {
        guard let panel else { return }
        isDragging = true
        let mouse = NSEvent.mouseLocation
        defer { lastDragMouse = mouse }
        guard let last = lastDragMouse else { return }   // first step: just anchor
        let origin = panel.frame.origin
        panel.setFrameOrigin(NSPoint(x: origin.x + (mouse.x - last.x),
                                     y: origin.y + (mouse.y - last.y)))
    }

    /// Persist where the user dropped the bar.
    func commitDrag() {
        lastDragMouse = nil
        guard let panel else { isDragging = false; return }
        defaults.set(Double(panel.frame.origin.x), forKey: originXKey)
        defaults.set(Double(panel.frame.origin.y), forKey: originYKey)
        isDragging = false
    }

    var hasCustomPosition: Bool { defaults.object(forKey: originXKey) != nil }

    /// Forget the custom position and snap back to the default spot.
    func resetPosition() {
        defaults.removeObject(forKey: originXKey)
        defaults.removeObject(forKey: originYKey)
        position()
    }

    func show() {
        guard let model else { return }
        if panel == nil { panel = makePanel(model: model) }
        hideToken += 1            // cancel any in-flight hide completion
        resizeForCurrentStyle()
        position()
        // Already up → just keep it frontmost; don't re-animate (avoids flicker
        // on recording → transcribing → formatting transitions).
        guard !visible else { panel?.orderFrontRegardless(); return }
        visible = true
        panel?.alphaValue = 0
        panel?.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            panel?.animator().alphaValue = 1
        }
    }

    func hide() {
        guard visible, let panel else { return }
        visible = false
        hideToken += 1
        let token = hideToken
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            // Only order out if no newer show/hide happened in the meantime.
            guard let self, self.hideToken == token, !self.visible else { return }
            panel.orderOut(nil)
        }
    }

    private func makePanel(model: AppModel) -> NSPanel {
        // Sized to the FlowBar including its transparent shadow margin.
        let size = panelSize(for: model)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false   // shadow is drawn by SwiftUI on the pill only
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let host = NSHostingView(rootView: FlowBar(model: model))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }

    /// Panel size = the current style's content size + the FlowBar's 26pt
    /// transparent shadow margin on every side. The landed confirmation always
    /// uses the compact pill, whatever the recording style.
    private func panelSize(for model: AppModel) -> NSSize {
        // The transient bars (landed / cancelled / notice) match the recording
        // style's height so nothing jumps: Ticker → its slim size, everything
        // else → the compact galley pill.
        let isTransient = model.landedAppName != nil || model.noticeText != nil || model.isCancelled
        let content: CGSize
        if isTransient {
            content = model.flowStyle == .ticker ? FlowBarStyle.ticker.contentSize
                                                 : FlowBarStyle.galley.contentSize
        } else {
            content = model.flowStyle.contentSize
        }
        return NSSize(width: content.width + 52, height: content.height + 52)
    }

    private func resizeForCurrentStyle() {
        guard let panel, let model else { return }
        let size = panelSize(for: model)
        if panel.frame.size != size { panel.setContentSize(size) }
    }

    /// Place the bar: at the user's dragged position if they've set one (clamped
    /// onto a real screen), otherwise pinned to the bottom-center of the screen
    /// under the pointer. Never fights an in-progress drag.
    private func position() {
        guard let panel, !isDragging else { return }
        let size = panel.frame.size
        if let origin = savedOrigin(for: size) {
            panel.setFrameOrigin(origin)
            return
        }
        let screen = screenUnderMouse() ?? NSScreen.main
        guard let screen else { return }
        let visibleFrame = screen.visibleFrame
        let x = visibleFrame.midX - size.width / 2
        let y = visibleFrame.minY + 12
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    /// The saved origin, clamped so the panel always lands fully on some screen
    /// (a monitor may have been unplugged since it was saved). Nil if unset.
    private func savedOrigin(for size: NSSize) -> NSPoint? {
        guard defaults.object(forKey: originXKey) != nil else { return nil }
        let saved = NSPoint(x: defaults.double(forKey: originXKey),
                            y: defaults.double(forKey: originYKey))
        let center = NSPoint(x: saved.x + size.width / 2, y: saved.y + size.height / 2)
        let screen = NSScreen.screens.first { NSMouseInRect(center, $0.frame, false) }
            ?? screenUnderMouse() ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return saved }
        return NSPoint(x: min(max(saved.x, vf.minX), vf.maxX - size.width),
                       y: min(max(saved.y, vf.minY), vf.maxY - size.height))
    }

    private func screenUnderMouse() -> NSScreen? {
        let loc = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(loc, $0.frame, false) }
    }
}
