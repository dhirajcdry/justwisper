import SwiftUI

/// The floating "Press" overlay shown while dictating, in the user's chosen
/// style (Settings ▸ Overlay): Galley (compact bar), Column (editorial card),
/// Ticker (slim dark tape), or Caption (just the floating words).
/// Confirmed words set in ink; words not yet confirmed are vermillion, with a
/// live caret.
struct FlowBar: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        Group {
            if model.flowStyle == .caption, model.isTransientBar {
                captionNote()
                    .onHover { model.setBarHover($0) }
            } else if let app = model.landedAppName {
                confirmBar(confirm(c)) { landedContent(app, c) }
                    .onHover { model.setBarHover($0) }
            } else if model.isCancelled {
                confirmBar(confirm(c)) { cancelledContent(c) }
                    .onHover { model.setBarHover($0) }
            } else if let message = model.noticeText {
                confirmBar(confirm(c)) { noticeContent(message, c) }
            } else {
                switch model.flowStyle {
                case .galley: pill(c) { galleyContent(c) }
                case .column: card(c, style: .column) { columnContent(c) }
                case .ticker: tickerBar(c)
                case .caption: captionContent()
                }
            }
        }
        // Two tight shadows: a crisp contact shadow + one soft ambient halo.
        // Both stay well inside the 30pt transparent margin below, so the blur
        // fades to nothing instead of being clipped into a hard "box/saddle" by
        // the window edge (the earlier, wider radius-20 shadow was getting cut).
        .shadow(color: .black.opacity(scheme == .dark ? 0.38 : 0.14), radius: 3,  y: 1)
        .shadow(color: .black.opacity(scheme == .dark ? 0.32 : 0.15), radius: 11, y: 6)
        // The whole bar is draggable. simultaneousGesture so the ✓/✕/COPY/UNDO
        // buttons still get plain taps — only an actual drag moves the bar.
        // Double-click anywhere resets to the default spot.
        .onTapGesture(count: 2) { model.resetOverlayPosition() }
        .simultaneousGesture(moveGesture)
        .padding(30) // transparent room so the soft shadow fully fades (no clip)
    }

    // MARK: - Drag to reposition

    /// Reposition by following the pointer in absolute screen space (handled in
    /// OverlayController) — no per-frame translation math here, so there's no
    /// feedback loop between "bar moved" and "next reading".
    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { _ in model.overlayDragStep() }
            .onEnded { _ in model.endOverlayDrag() }
    }

    // MARK: - Chrome

    /// The compact pill chrome (Galley + landed confirmation).
    private func pill<Content: View>(_ c: Palette, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
            .frame(width: FlowBarStyle.galley.contentSize.width,
                   height: FlowBarStyle.galley.contentSize.height)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(c.panel)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(c.ink.opacity(0.9), lineWidth: 1))
            )
    }

    /// The editorial card chrome (Column).
    private func card<Content: View>(_ c: Palette, style: FlowBarStyle,
                                     @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(width: style.contentSize.width, height: style.contentSize.height)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(c.panel))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(c.ink.opacity(0.9), lineWidth: 1))
    }

    // MARK: - Confirmation chrome (landed / cancelled / notice)

    /// Colors + height for the transient bars, matched to the chosen recording
    /// style so the confirmation is the SAME height & look as the bar you were
    /// just watching — no jarring resize (esp. the slim dark Ticker → 40px).
    private struct Confirm {
        let ink, ink2, accent, btnBg, btnBorder, chrome, border: Color
        let width, height: CGFloat
        let ticker: Bool
    }

    private func confirm(_ c: Palette) -> Confirm {
        if model.flowStyle == .ticker {
            return Confirm(ink: Color(hex: 0xE8E1D0), ink2: Color(hex: 0xC3BAA6),
                           accent: Color(hex: 0xFF7A4D),
                           btnBg: .white.opacity(0.09), btnBorder: .white.opacity(0.16),
                           chrome: Color(hex: 0x1A1712), border: .clear,
                           width: FlowBarStyle.ticker.contentSize.width,
                           height: FlowBarStyle.ticker.contentSize.height, ticker: true)
        }
        // Galley / Column / Caption all confirm as the compact light pill.
        return Confirm(ink: c.ink, ink2: c.ink2, accent: c.sig,
                       btnBg: c.paper, btnBorder: c.line, chrome: c.panel, border: c.ink.opacity(0.9),
                       width: FlowBarStyle.galley.contentSize.width,
                       height: FlowBarStyle.galley.contentSize.height, ticker: false)
    }

    private func confirmBar<Content: View>(_ k: Confirm, @ViewBuilder _ content: () -> Content) -> some View {
        let radius: CGFloat = k.ticker ? 9 : 13
        return content()
            .padding(.leading, k.ticker ? 14 : 16)
            .padding(.trailing, k.ticker ? 12 : 8)
            .frame(width: k.width, height: k.height)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(k.chrome)
                    .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(k.border, lineWidth: 1))
            )
    }

    /// A labelled action button (COPY / UNDO / RETRY), sized to the bar.
    private func confirmAction(_ label: String, icon: String, filled: Bool, _ k: Confirm,
                               action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: k.ticker ? 10 : 11, weight: .semibold))
                Text(label).font(F.monoSemi(k.ticker ? 10 : 11)).tracking(1.2)
            }
            .foregroundStyle(filled ? .white : k.ink2)
            .padding(.horizontal, k.ticker ? 10 : 11)
            .frame(height: k.ticker ? 26 : 28)
            .background(RoundedRectangle(cornerRadius: 7).fill(filled ? k.accent : k.btnBg))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(filled ? k.accent : k.btnBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func confirmDismiss(_ k: Confirm, action: @escaping () -> Void) -> some View {
        let s: CGFloat = k.ticker ? 26 : 28
        return Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: k.ticker ? 11 : 12, weight: .bold))
                .foregroundStyle(k.ink2)
                .frame(width: s, height: s)
                .background(RoundedRectangle(cornerRadius: k.ticker ? 6 : 8).fill(k.btnBg))
                .overlay(RoundedRectangle(cornerRadius: k.ticker ? 6 : 8)
                    .strokeBorder(k.btnBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3a · Galley (compact bar)

    private func galleyContent(_ c: Palette) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                RecDot(color: c.sig, live: !model.isBusy)
                Text(model.recordingClock)
                    .font(F.monoMed(12.5)).foregroundStyle(c.ink).monospacedDigit()
            }
            .fixedSize()

            divider(c.line)

            Group {
                if finishing {
                    oneLineFlow(fontName: F.mediumName, size: 15, committed: c.ink, accent: c.sig)
                } else if model.isBusy {
                    busyRow(c.sig, label: model.busyLabel, dim: c.ink3)
                } else if model.partialText.isEmpty {
                    WaveformView(levels: model.levels, color: c.sig, barWidth: 2)
                        .frame(maxWidth: .infinity)
                } else {
                    oneLineFlow(fontName: F.mediumName, size: 15, committed: c.ink, accent: c.sig)
                }
            }
            .frame(maxWidth: .infinity)

            divider(c.line)

            if finishing {
                busyChip(c.sig, dim: c.ink2)
            } else {
                iconButton("xmark", size: 28, bg: c.paper, fg: c.ink2, border: c.line) { model.cancelRecording() }
                iconButton("checkmark", size: 28, bg: c.sig, fg: .white, border: c.sig) { model.endRecording() }
            }
        }
    }

    // MARK: - 3b · Column (editorial card)

    private func columnContent(_ c: Palette) -> some View {
        VStack(spacing: 0) {
            cardHeader(c, waveWidth: 58)

            wrappedFlow(c, size: 22)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .clipped()
                .mask(topFade)

            cardFooter(c) {
                Text("\(liveWordCount) WORDS · \(model.recordingClock)")
                    .font(F.mono(10)).tracking(1.2).foregroundStyle(c.ink2).monospacedDigit()
            }
        }
    }

    // MARK: - 3c · Ticker (slim dark tape — same in light & dark)

    private func tickerBar(_ c: Palette) -> some View {
        let ink = Color(hex: 0xE8E1D0)
        let sig = Color(hex: 0xFF7A4D)
        let dim = Color(hex: 0xC3BAA6)
        let line = Color(hex: 0x3A352B)
        return HStack(spacing: 11) {
            HStack(spacing: 7) {
                RecDot(color: sig, live: !model.isBusy)
                Text("REC").font(F.mono(10)).tracking(1.6).foregroundStyle(model.isBusy ? dim : sig)
                if model.handsFree { handsFreeMark(sig) }
            }
            .fixedSize()

            divider(line)

            Group {
                if finishing {
                    oneLineFlow(fontName: F.monoMedName, size: 12.5, committed: ink, accent: sig)
                } else if model.isBusy {
                    busyRow(sig, label: model.busyLabel, dim: dim)
                } else if model.partialText.isEmpty {
                    Text("listening…")
                        .font(F.mono(11)).tracking(1).foregroundStyle(dim)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    oneLineFlow(fontName: F.monoMedName, size: 12.5, committed: ink, accent: sig)
                }
            }
            .frame(maxWidth: .infinity)

            divider(line)

            Text(model.recordingClock)
                .font(F.mono(11)).foregroundStyle(dim).monospacedDigit()

            if finishing {
                busyChip(sig, dim: dim)
            } else {
                bareButton("xmark", fg: dim) { model.cancelRecording() }
                bareButton("checkmark", fg: sig) { model.endRecording() }
            }
        }
        .padding(.horizontal, 14)
        .frame(width: FlowBarStyle.ticker.contentSize.width,
               height: FlowBarStyle.ticker.contentSize.height)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(hex: 0x1A1712)))
    }

    // MARK: - 3d · Caption (just the words)

    /// No chrome at all — the live line floats on its own like a subtitle.
    /// Light text with a dark halo stays legible over any background; the
    /// transparent space around it passes clicks through to the app below.
    private func captionContent() -> some View {
        let ink = Color(hex: 0xF7F3EA)
        let sig = Color(hex: 0xFF7A4D)
        return Group {
            if model.live.words.isEmpty {
                Text(model.isBusy ? "finishing…" : "listening…")
                    .font(F.medium(15)).foregroundStyle(ink.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
                oneLineFlow(fontName: F.semiboldName, size: 19, committed: ink, accent: sig)
            }
        }
        .shadow(color: .black.opacity(0.85), radius: 1.2)
        .shadow(color: .black.opacity(0.55), radius: 7)
        .padding(.horizontal, 16)
        .frame(width: FlowBarStyle.caption.contentSize.width,
               height: FlowBarStyle.caption.contentSize.height)
    }

    /// Caption's transient states — landed / cancelled / notice — as one more
    /// floating line where the words just were: no bar, the action is a word.
    private func captionNote() -> some View {
        let ink = Color(hex: 0xF7F3EA)
        let dim = ink.opacity(0.72)
        let sig = Color(hex: 0xFF7A4D)
        return HStack(spacing: 12) {
            Spacer(minLength: 0)
            if let app = model.landedAppName {
                if model.landedCopied {
                    (Text("copied — ").foregroundColor(dim) + Text("⌘V").foregroundColor(ink)
                     + Text(" to paste anywhere").foregroundColor(dim))
                        .modifier(Arrive())
                        .id("copied")
                } else {
                    HStack(spacing: 7) {
                        Image(systemName: model.deliveryConfirmed ? "checkmark" : "arrow.up.right")
                            .font(.system(size: 14, weight: .heavy)).foregroundStyle(sig)
                            .modifier(Pop())
                        (Text(model.deliveryConfirmed ? "in " : "sent to ").foregroundColor(dim)
                         + Text(app).foregroundColor(ink))
                            .lineLimit(1)
                    }
                    .modifier(Arrive())
                    CaptionLink(title: "copy", color: dim) { model.copyLastTranscript() }
                        .help("Copy this text so you can paste it (⌘V) anywhere")
                        .modifier(Arrive(delay: 0.12))
                }
            } else if model.isCancelled {
                Text("cancelled").foregroundStyle(dim)
                    .modifier(Arrive())
                CaptionLink(title: "undo", color: sig, bold: true) { model.undoCancel() }
                    .help("Transcribe the take you just cancelled")
                    .modifier(Arrive(delay: 0.08))
            } else if let message = model.noticeText {
                HStack(spacing: 7) {
                    Text("!").font(F.extrabold(17)).foregroundStyle(sig)
                    Text(message).foregroundStyle(ink)
                        .font(F.semibold(15))
                        .lineLimit(1).minimumScaleFactor(0.8).truncationMode(.middle)
                }
                .modifier(Arrive())
                if model.noticeCanRetry {
                    CaptionLink(title: "retry", color: sig, bold: true) { model.retryModelLoad() }
                        .modifier(Arrive(delay: 0.08))
                }
            }
        }
        .font(F.semibold(17))
        .shadow(color: .black.opacity(0.85), radius: 1.2)
        .shadow(color: .black.opacity(0.55), radius: 7)
        .padding(.horizontal, 16)
        .frame(width: FlowBarStyle.caption.contentSize.width,
               height: FlowBarStyle.caption.contentSize.height)
    }

    // MARK: - Shared card pieces

    private func cardHeader(_ c: Palette, waveWidth: CGFloat) -> some View {
        HStack {
            HStack(spacing: 8) {
                RecDot(color: c.sig, live: !model.isBusy)
                Text(model.isBusy ? model.busyLabel : "DICTATING")
                    .font(F.mono(10)).tracking(1.6).foregroundStyle(c.sig)
                if model.handsFree { handsFreeMark(c.sig) }
            }
            Spacer()
            WaveformView(levels: model.levels, color: c.sig, barWidth: 2)
                .frame(width: waveWidth, height: 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Rectangle().fill(c.line).frame(height: 1) }
    }

    private func cardFooter<Leading: View>(_ c: Palette,
                                           @ViewBuilder leading: () -> Leading) -> some View {
        HStack(spacing: 8) {
            leading()
            Spacer()
            if model.isBusy {
                busyChip(c.sig, dim: c.ink2).frame(height: 28)
            } else {
                iconButton("xmark", size: 28, bg: c.paper, fg: c.ink2, border: c.line) { model.cancelRecording() }
                iconButton("checkmark", size: 28, bg: c.sig, fg: .white, border: c.sig) { model.endRecording() }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .top) { Rectangle().fill(c.line).frame(height: 1) }
    }

    /// Fades the oldest (topmost) wrapped lines, like the design's set type rising away.
    private var topFade: LinearGradient {
        LinearGradient(stops: [.init(color: .clear, location: 0),
                               .init(color: .black, location: 0.35),
                               .init(color: .black, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }

    // MARK: - Landed confirmation

    /// Brief post-paste confirmation: where the words landed. "Copy" puts the
    /// text back on the clipboard so it can be pasted (⌘V) anywhere — reliable
    /// everywhere, unlike a synthetic undo.
    private func landedContent(_ app: String, _ c: Palette) -> some View {
        let k = confirm(c)
        return HStack(spacing: k.ticker ? 10 : 13) {
            Image(systemName: model.deliveryConfirmed ? "checkmark.circle.fill" : "paperplane")
                .font(.system(size: k.ticker ? 15 : 17, weight: .semibold))
                .foregroundStyle(k.accent)
            if model.landedCopied {
                (Text("Copied — press ").foregroundColor(k.ink2)
                 + Text("⌘V").foregroundColor(k.ink)
                 + Text(" to paste anywhere").foregroundColor(k.ink2))
                    .font(F.medium(k.ticker ? 13 : 15)).lineLimit(1)
                Spacer(minLength: 6)
            } else {
                (Text(model.deliveryConfirmed ? "Landed in " : "Sent to ").foregroundColor(k.ink2) + Text(app).foregroundColor(k.ink))
                    .font(F.medium(k.ticker ? 13 : 15)).lineLimit(1)
                Spacer(minLength: 6)
                confirmAction("COPY", icon: "doc.on.doc", filled: false, k) { model.copyLastTranscript() }
                    .help("Copy this text so you can paste it (⌘V) anywhere")
            }
            confirmDismiss(k) { model.cancelRecording() }
        }
    }

    /// Why dictation can't start right now — shown when the hotkey is pressed
    /// while the model is loading or broken, so it never fails silently.
    private func noticeContent(_ message: String, _ c: Palette) -> some View {
        let k = confirm(c)
        return HStack(spacing: k.ticker ? 10 : 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: k.ticker ? 15 : 17, weight: .semibold))
                .foregroundStyle(k.accent)
            Text(message)
                .font(F.medium(k.ticker ? 12 : 13.5)).foregroundStyle(k.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            if model.noticeCanRetry {
                confirmAction("RETRY", icon: "arrow.clockwise", filled: true, k) { model.retryModelLoad() }
            }
            confirmDismiss(k) { model.dismissNotice() }
        }
    }

    /// Post-cancel bar: the take was held, one click recovers it. The primary
    /// (vermillion) action is Undo; ✕ lets it go for good.
    private func cancelledContent(_ c: Palette) -> some View {
        let k = confirm(c)
        return HStack(spacing: k.ticker ? 10 : 13) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .font(.system(size: k.ticker ? 15 : 17, weight: .semibold))
                .foregroundStyle(k.ink2)
            (Text("Cancelled").foregroundColor(k.ink)
             + Text(" — recover it?").foregroundColor(k.ink2))
                .font(F.medium(k.ticker ? 13 : 15)).lineLimit(1)
            Spacer(minLength: 6)
            confirmAction("UNDO", icon: "arrow.uturn.backward", filled: true, k) { model.undoCancel() }
                .help("Transcribe the take you just cancelled")
            confirmDismiss(k) { model.cancelRecording() }
        }
    }

    // MARK: - Flowing text

    /// One line, newest on the right, moving like a tape: the whole row slides
    /// left as one piece and new words emerge from behind the caret. Words stay
    /// in the accent color until a later pass confirms them; older words slide
    /// off under a soft left-edge fade.
    private func oneLineFlow(fontName: String, size: CGFloat, committed: Color, accent: Color) -> some View {
        HStack(spacing: 3) {
            TapeRow(words: Array(model.live.words.suffix(40)), fontName: fontName, size: size,
                    ink: committed, accent: finishing ? committed : accent)
                .equatable()
                .modifier(Settling(active: finishing))
            if !finishing { Caret(color: accent) }
        }
    }

    /// Wrapped editorial flow (Column): words wrap and rise; words not yet
    /// confirmed by a second pass are accented.
    @ViewBuilder
    private func wrappedFlow(_ c: Palette, size: CGFloat) -> some View {
        if model.live.words.isEmpty {
            Text("Listening…")
                .font(F.medium(size)).foregroundStyle(c.ink3)
        } else {
            WordFlow(spacing: size * 0.26, lineSpacing: 3) {
                ForEach(model.live.words) { w in
                    LiveWordView(word: w, font: F.medium(size), ink: c.ink,
                                 accent: finishing ? c.ink : c.sig)
                }
                if !finishing { Text("▎").font(F.medium(size)).foregroundStyle(c.sig) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(Settling(active: finishing))
        }
    }

    /// Recording stopped and the final pass is running: keep the words you just
    /// watched on screen (settling) instead of swapping them for a spinner.
    private var finishing: Bool { model.isBusy && !model.live.words.isEmpty }

    /// Replaces ✕/✓ while the take is finishing — they can't act then anyway.
    private func busyChip(_ tint: Color, dim: Color) -> some View {
        HStack(spacing: 6) {
            ProgressView().controlSize(.mini).tint(tint)
            Text(model.state == .formatting ? "POLISHING" : "FINISHING")
                .font(F.mono(10)).tracking(1.2).foregroundStyle(dim)
        }
        .fixedSize()
        .padding(.horizontal, 4)
    }

    private var liveWordCount: Int {
        model.partialText.split(separator: " ").count
    }

    // MARK: - Small pieces

    private func busyRow(_ tint: Color, label: String, dim: Color) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small).tint(tint)
            Text(label).font(F.mono(11)).tracking(1.4).foregroundStyle(dim)
        }
        .frame(maxWidth: .infinity)
    }

    private func handsFreeMark(_ color: Color) -> some View {
        Image(systemName: "infinity")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color)
            .help("Hands-free — tap Right ⌥ to stop")
    }

    private func divider(_ color: Color) -> some View {
        Rectangle().fill(color).frame(width: 1, height: 20)
    }

    private func iconButton(_ symbol: String, size: CGFloat, bg: Color, fg: Color, border: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.37, weight: .bold))
                .foregroundStyle(fg)
                .frame(width: size, height: size)
                .background(RoundedRectangle(cornerRadius: size * 0.21).fill(bg))
                .overlay(RoundedRectangle(cornerRadius: size * 0.21).strokeBorder(border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Chromeless icon button for the Ticker tape.
    private func bareButton(_ symbol: String, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(fg)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
    }
}

private struct RecDot: View {
    var color: Color
    /// False once recording stops: a still, dimmed dot instead of the blink.
    var live = true
    var body: some View {
        if live { blinking } else {
            Circle().fill(color.opacity(0.35)).frame(width: 9, height: 9)
        }
    }

    private var blinking: some View {
        TimelineView(.periodic(from: .now, by: 0.7)) { t in
            let on = Int(t.date.timeIntervalSinceReferenceDate / 0.7) % 2 == 0
            Circle().fill(color).frame(width: 9, height: 9)
                .opacity(on ? 1 : 0.35)
                .shadow(color: color.opacity(0.5), radius: 3)
        }
    }
}

private struct Caret: View {
    var color: Color
    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { t in
            let on = Int(t.date.timeIntervalSinceReferenceDate / 0.5) % 2 == 0
            Rectangle().fill(color).frame(width: 2, height: 17).opacity(on ? 1 : 0)
        }
    }
}

/// A live word: rises in (staggered with its burst), shows tentative until a
/// later pass confirms it, and flashes briefly when it replaced a different word.
private struct LiveWordView: View {
    let word: LiveWord
    let font: Font
    let ink: Color
    let accent: Color
    /// Wrapped styles rise each word into place, staggered; on the tape the row's
    /// slide already carries the motion, so words just fade in, immediately.
    var rises = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    @State private var flash: Bool

    init(word: LiveWord, font: Font, ink: Color, accent: Color, rises: Bool = true) {
        self.word = word
        self.font = font
        self.ink = ink
        self.accent = accent
        self.rises = rises
        _flash = State(initialValue: word.revised)
        // Already-confirmed words (bar reopened, style switched) don't replay their entrance.
        _shown = State(initialValue: word.settled)
    }

    var body: some View {
        let tentative = !word.settled
        let rising = !shown && rises && !reduceMotion
        Text(word.text)
            .font(font)
            .foregroundStyle(tentative ? accent : ink)
            .fixedSize()
            .background(RoundedRectangle(cornerRadius: 3)
                .fill(accent.opacity(flash ? 0.28 : 0))
                .padding(.horizontal, -2))
            .opacity(shown ? 1 : 0)
            .offset(y: rising ? 4 : 0)
            .animation(.easeOut(duration: 0.4), value: tentative)
            .onAppear {
                withAnimation(.easeOut(duration: rises ? 0.2 : 0.16).delay(rises ? word.delay : 0)) { shown = true }
                if flash {
                    withAnimation(.easeOut(duration: 0.7).delay(0.2)) { flash = false }
                }
            }
    }
}

/// Left-to-right wrapping layout for live words (Text concatenation can't give
/// each word its own identity, so this stands in for it).
private struct WordFlow: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let used = rows.map(\.width).max() ?? 0
        // Never ask for more height than offered: newest lines sit at the bottom
        // and older ones run off the top, where the card clips and fades them.
        return CGSize(width: proposal.width ?? used, height: min(height, proposal.height ?? height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews, width: bounds.width)
        let overflow = max(0, (rows.last.map { $0.y + $0.height } ?? 0) - bounds.height)
        for row in rows {
            for (i, x) in zip(row.indices, row.xs) {
                subviews[i].place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + row.y + row.height - overflow),
                                  anchor: .bottomLeading, proposal: .unspecified)
            }
        }
    }

    private struct Row { var indices: [Int] = []; var xs: [CGFloat] = []
                         var width: CGFloat = 0; var height: CGFloat = 0; var y: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            var row = rows[rows.count - 1]
            let x = row.indices.isEmpty ? 0 : row.width + spacing
            if !row.indices.isEmpty, x + size.width > width {
                let y = row.y + row.height + lineSpacing
                rows.append(Row(y: y))
                row = rows[rows.count - 1]
                row.indices = [i]; row.xs = [0]; row.width = size.width; row.height = size.height
            } else {
                row.indices.append(i); row.xs.append(x)
                row.width = x + size.width; row.height = max(row.height, size.height)
            }
            rows[rows.count - 1] = row
        }
        return rows
    }
}

/// The one-line live row. Its width is measured up front (same font as drawn),
/// so when words arrive the row is offset back by exactly the added width and
/// eased to rest in one motion — every word moves together, nothing overlaps,
/// and no frame ever shows the row in the wrong place.
private struct TapeRow: View, Equatable {
    let words: [LiveWord]
    let fontName: String
    let size: CGFloat
    let ink: Color
    let accent: Color

    var body: some View {
        let font = Font.custom(fontName, size: size)
        let space = Self.width(" ", fontName, size)
        let width = words.reduce(0) { $0 + Self.width($1.text, fontName, size) }
            + space * CGFloat(max(words.count - 1, 0))
        Color.clear
            .frame(maxWidth: .infinity, minHeight: ceil(size * 1.5), maxHeight: ceil(size * 1.5))
            .overlay(alignment: .trailing) {
                HStack(spacing: space) {
                    ForEach(words) { w in
                        LiveWordView(word: w, font: font, ink: ink, accent: accent, rises: false)
                    }
                }
                .fixedSize()
                .animation(.easeOut(duration: 0.2)) {
                    $0.modifier(TapeSlide(shown: width, target: width))
                }
            }
            .clipped()
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0),
                                         .init(color: .black, location: 0.12),
                                         .init(color: .black, location: 0.97),
                                         .init(color: .clear, location: 1)],
                                 startPoint: .leading, endPoint: .trailing))
    }

    static func width(_ text: String, _ fontName: String, _ size: CGFloat) -> CGFloat {
        let font = NSFont(name: fontName, size: size) ?? .systemFont(ofSize: size)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

/// Offsets the row by (target − shown). `shown` animates; `target` doesn't, so
/// on the first frame after a change the row sits exactly where it was, then
/// glides left by the added width.
private struct TapeSlide: ViewModifier, Animatable {
    var shown: CGFloat
    let target: CGFloat
    var animatableData: CGFloat {
        get { shown }
        set { shown = newValue }
    }
    func body(content: Content) -> some View {
        content.offset(x: target - shown)
    }
}

/// While the final pass runs, the live words dim and a soft band of light
/// sweeps across them left to right — "being finalised", without new motion
/// on the words themselves. Always applied (opaque when inactive) so toggling
/// it never rebuilds the words underneath.
private struct Settling: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweep = false

    func body(content: Content) -> some View {
        content
            .mask {
                GeometryReader { g in
                    let band = max(g.size.width * 0.35, 60)
                    ZStack(alignment: .leading) {
                        Color.black.opacity(active ? 0.42 : 1)
                        if active && !reduceMotion {
                            LinearGradient(colors: [.clear, .black, .clear],
                                           startPoint: .leading, endPoint: .trailing)
                                .frame(width: band)
                                .offset(x: sweep ? g.size.width : -band)
                        }
                    }
                }
            }
            .onChange(of: active, initial: true) { _, on in
                sweep = false
                guard on else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { sweep = true }
            }
    }
}

/// A word that acts: underlines on hover, the only "button" Caption shows.
private struct CaptionLink: View {
    let title: String
    let color: Color
    var bold = false
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(bold ? F.extrabold(17) : F.semibold(17))
                .underline(true, color: color.opacity(hover ? 1 : 0.45))
                .foregroundStyle(color)
                .padding(.vertical, 4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}

/// Rises a few points into place and fades in — once, on appear.
private struct Arrive: ViewModifier {
    var delay: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 6)
            .onAppear { withAnimation(.easeOut(duration: 0.24).delay(delay)) { shown = true } }
    }
}

/// A small spring pop for the landed check.
private struct Pop: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(shown || reduceMotion ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { shown = true } }
    }
}
