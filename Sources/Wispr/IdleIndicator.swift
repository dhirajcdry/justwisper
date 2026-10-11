import SwiftUI
import AppKit

/// What the always-on mark is saying.
enum IndicatorStatus: Equatable {
    case ready       // hold Right ⌥ to talk
    case loading     // the speech model is still loading — don't talk yet
    case attention   // a permission is missing or the model failed
}

/// Hover state, driven by the controller's pointer tracking (the panel ignores
/// the mouse until the pointer is actually on the pill).
@MainActor
final class IndicatorHover: ObservableObject {
    @Published var on = false
}

/// The small always-on mark that says "justwisper is here and listening for
/// Right ⌥". It sits exactly where the flow bar appears — wherever the user
/// dragged it — so the bar grows out of the same spot when dictation starts.
///
/// A separate panel from the flow bar: it never takes clicks outside the pill
/// (ignoresMouseEvents until the pointer is on it), skips full-screen Spaces,
/// and is excluded from screen sharing and screenshots.
@MainActor
final class IdleIndicatorController {
    /// Pill sizes (content only). Rest is barely there; hover reveals the hint.
    static let restSize = CGSize(width: 38, height: 10)
    static let hoverSize = CGSize(width: 156, height: 26)
    /// Transparent room around the pill inside the panel (for the hover size).
    private static let margin: CGFloat = 8
    private static var panelSize: NSSize {
        NSSize(width: hoverSize.width + margin * 2, height: hoverSize.height + margin * 2)
    }

    private var panel: NSPanel?
    private weak var model: AppModel?
    private weak var overlay: OverlayController?
    private let hover = IndicatorHover()
    private var visible = false
    private var fadeToken = 0
    private var monitors: [Any] = []
    private var screenObserver: NSObjectProtocol?
    private var dragLast: NSPoint?

    func configure(model: AppModel, overlay: OverlayController) {
        self.model = model
        self.overlay = overlay
    }

    func show() {
        guard let model else { return }
        if panel == nil { panel = makePanel(model: model) }
        fadeToken += 1
        position()
        guard !visible, let panel else { return }
        visible = true
        startTracking()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard visible, let panel else { return }
        visible = false
        stopTracking()
        hover.on = false
        panel.ignoresMouseEvents = true
        fadeToken += 1
        let token = fadeToken
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard let self, self.fadeToken == token, !self.visible else { return }
                panel.orderOut(nil)
            }
        }
    }

    /// Re-anchor to the bar's spot (it moved, the style changed, a display changed).
    func reposition() { if visible { position() } }

    // MARK: - Panel

    private func makePanel(model: AppModel) -> NSPanel {
        let size = Self.panelSize
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
        // Every desktop, but not over full-screen apps (no .fullScreenAuxiliary).
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        // Keep it out of screen shares, recordings and screenshots.
        panel.sharingType = .none
        let host = NSHostingView(rootView: IndicatorPill(model: model, hover: hover,
                                                         onTap: { [weak self] in self?.tapped() },
                                                         onDrag: { [weak self] in self?.dragStep() },
                                                         onDragEnd: { [weak self] in self?.dragEnd() }))
        host.frame = NSRect(origin: .zero, size: size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in MainActor.assumeIsolated { self?.reposition() } }
        return panel
    }

    /// Centered on the bar, bottom edges aligned: the pill is where the bar's
    /// base will be, so the bar appears to grow out of it.
    private func position() {
        guard let panel, dragLast == nil, let bar = overlay?.barContentFrame() else { return }
        let size = Self.panelSize
        panel.setFrame(NSRect(x: (bar.midX - size.width / 2).rounded(),
                              y: (bar.minY - Self.margin).rounded(),
                              width: size.width, height: size.height), display: false)
    }

    // MARK: - Pointer tracking

    /// The panel only takes the mouse while the pointer is on the pill, so the
    /// transparent area around it never blocks clicks in the app underneath.
    private func startTracking() {
        guard monitors.isEmpty else { return }
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.trackPointer() }
        }) { monitors.append(global) }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            MainActor.assumeIsolated { self?.trackPointer() }
            return event
        }) { monitors.append(local) }
        trackPointer()
    }

    private func stopTracking() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
    }

    private func trackPointer() {
        guard let panel, visible else { return }
        if dragLast != nil { return }               // keep the grab during a drag
        let size = hover.on ? Self.hoverSize : Self.restSize
        let slop: CGFloat = hover.on ? 4 : 7         // a forgiving target at rest
        let frame = panel.frame
        let pill = NSRect(x: frame.midX - size.width / 2,
                          y: frame.minY + Self.margin,
                          width: size.width, height: size.height).insetBy(dx: -slop, dy: -slop)
        let inside = pill.contains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }
        if hover.on != inside {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { hover.on = inside }
        }
    }

    // MARK: - Actions

    private func tapped() {
        guard let model else { return }
        if model.indicatorStatus == .attention {
            MainWindow.show()
        } else {
            model.startHandsFreeFromIndicator()
        }
    }

    /// Dragging the pill moves the bar's spot too — they're one place.
    private func dragStep() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        defer { dragLast = mouse }
        guard let last = dragLast else { return }
        panel.setFrameOrigin(NSPoint(x: panel.frame.origin.x + mouse.x - last.x,
                                     y: panel.frame.origin.y + mouse.y - last.y))
    }

    private func dragEnd() {
        dragLast = nil
        guard let panel else { return }
        overlay?.anchorBar(bottomCenter: NSPoint(x: panel.frame.midX, y: panel.frame.minY + Self.margin))
        model?.overlayPositionChanged()
        position()
        trackPointer()
    }
}

// MARK: - The pill

private struct IndicatorPill: View {
    @ObservedObject var model: AppModel
    @ObservedObject var hover: IndicatorHover
    let onTap: () -> Void
    let onDrag: () -> Void
    let onDragEnd: () -> Void

    private static let ink = Color(hex: 0x1A1712)
    private static let cream = Color(hex: 0xEFE9DC)
    private static let sig = Color(hex: 0xFF6A43)

    var body: some View {
        let status = model.indicatorStatus
        let open = hover.on
        let size = open ? IdleIndicatorController.hoverSize : IdleIndicatorController.restSize
        VStack {
            Spacer(minLength: 0)
            ZStack {
                Capsule().fill(Self.ink.opacity(open ? 0.92 : 0.62))
                Capsule().strokeBorder(Color.white.opacity(open ? 0.18 : 0.3), lineWidth: 0.75)
                HStack(spacing: open ? 8 : 0) {
                    Mark(open: open, color: status == .attention ? Self.sig : Self.cream)
                        .opacity(status == .loading ? 0.4 : 1)
                    if open {
                        hint(status)
                            .font(F.mono(10.5)).tracking(0.3)
                            .foregroundStyle(Self.cream.opacity(0.88))
                            .lineLimit(1)
                            .fixedSize()
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, open ? 11 : 0)
                if status == .attention, !open {
                    Circle().fill(Self.sig).frame(width: 4, height: 4)
                        .offset(x: size.width / 2 - 1, y: -size.height / 2 + 1)
                }
            }
            .frame(width: size.width, height: size.height)
            .shadow(color: .black.opacity(open ? 0.3 : 0), radius: 6, y: 2)
            .contentShape(Capsule())
            .onTapGesture(perform: onTap)
            .gesture(DragGesture(minimumDistance: 3, coordinateSpace: .global)
                .onChanged { _ in onDrag() }
                .onEnded { _ in onDragEnd() })
            .help("justwisper")
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hint(_ status: IndicatorStatus) -> Text {
        switch status {
        case .ready:
            // The mono face has no proper ⌥ — set just that glyph in the system font.
            return Text("hold ") + Text("⌥").font(.system(size: 10.5, weight: .medium)) + Text(" or click")
        case .loading: return Text("loading model…")
        case .attention: return Text("needs setup")
        }
    }
}

/// The justwisper mark (the menu bar's five-bar waveform), scaled to the pill.
private struct Mark: View {
    let open: Bool
    let color: Color

    var body: some View {
        let heights: [CGFloat] = open ? [4, 8, 11, 7, 4] : [2.2, 4, 5.5, 3.6, 2.2]
        let width: CGFloat = open ? 2 : 1.4
        HStack(spacing: open ? 1.8 : 1.3) {
            ForEach(heights.indices, id: \.self) { i in
                Capsule().fill(color).frame(width: width, height: heights[i])
            }
        }
    }
}
