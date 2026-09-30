import SwiftUI

/// The floating "Press" overlay shown while dictating, in the user's chosen
/// style (Settings ▸ Overlay): Galley (compact bar), Column (editorial card),
/// Ticker (slim dark tape), or Proof (underline-while-refining sheet).
/// Final words set in ink; the word being recognised is vermillion (or
/// underlined, in Proof), with a live caret.
struct FlowBar: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        Group {
            if let app = model.landedAppName {
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
                case .proof: card(c, style: .proof) { proofContent(c) }
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
            .padding(.trailing, 11)
            .padding(.vertical, 10)
            .frame(width: FlowBarStyle.galley.contentSize.width,
                   height: FlowBarStyle.galley.contentSize.height)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(c.panel)
                    .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(c.ink.opacity(0.9), lineWidth: 1))
            )
    }

    /// The editorial card chrome (Column + Proof).
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
        // Galley / Column / Proof all confirm as the compact light pill.
        return Confirm(ink: c.ink, ink2: c.ink2, accent: c.sig,
                       btnBg: c.paper, btnBorder: c.line, chrome: c.panel, border: c.ink.opacity(0.9),
                       width: FlowBarStyle.galley.contentSize.width,
                       height: FlowBarStyle.galley.contentSize.height, ticker: false)
    }

    private func confirmBar<Content: View>(_ k: Confirm, @ViewBuilder _ content: () -> Content) -> some View {
        let radius: CGFloat = k.ticker ? 9 : 13
        return content()
            .padding(.leading, k.ticker ? 14 : 16)
            .padding(.trailing, k.ticker ? 12 : 11)
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
            .padding(.horizontal, k.ticker ? 10 : 13)
            .frame(height: k.ticker ? 26 : 38)
            .background(RoundedRectangle(cornerRadius: 7).fill(filled ? k.accent : k.btnBg))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(filled ? k.accent : k.btnBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func confirmDismiss(_ k: Confirm, action: @escaping () -> Void) -> some View {
        let s: CGFloat = k.ticker ? 26 : 38
        return Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: k.ticker ? 11 : 14, weight: .bold))
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
        HStack(spacing: 13) {
            HStack(spacing: 8) {
                RecDot(color: c.sig)
                Text(model.recordingClock)
                    .font(F.monoMed(13)).foregroundStyle(c.ink).monospacedDigit()
                if model.handsFree { handsFreeMark(c.sig) }
            }
            .fixedSize()

            divider(c.line)

            Group {
                if model.isBusy {
                    busyRow(c.sig, label: model.busyLabel, dim: c.ink3)
                } else if model.partialText.isEmpty {
                    WaveformView(levels: model.levels, color: c.sig, barWidth: 2)
                        .frame(maxWidth: .infinity)
                } else {
                    oneLineFlow(font: F.medium(15), committed: c.ink, accent: c.sig)
                }
            }
            .frame(maxWidth: .infinity)

            divider(c.line)

            iconButton("xmark", size: 38, bg: c.paper, fg: c.ink2, border: c.line) { model.cancelRecording() }
            iconButton("checkmark", size: 38, bg: c.sig, fg: .white, border: c.sig) { model.endRecording() }
        }
    }

    // MARK: - 3b · Column (editorial card)

    private func columnContent(_ c: Palette) -> some View {
        VStack(spacing: 0) {
            cardHeader(c, waveWidth: 58)

            wrappedFlow(c, size: 22, underlineInterim: false)
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
                RecDot(color: sig)
                Text("REC").font(F.mono(10)).tracking(1.6).foregroundStyle(sig)
                if model.handsFree { handsFreeMark(sig) }
            }
            .fixedSize()

            divider(line)

            Group {
                if model.isBusy {
                    busyRow(sig, label: model.busyLabel, dim: dim)
                } else if model.partialText.isEmpty {
                    Text("listening…")
                        .font(F.mono(11)).tracking(1).foregroundStyle(dim)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    oneLineFlow(font: F.monoMed(12.5), committed: ink, accent: sig)
                }
            }
            .frame(maxWidth: .infinity)

            divider(line)

            Text(model.recordingClock)
                .font(F.mono(11)).foregroundStyle(dim).monospacedDigit()

            bareButton("xmark", fg: dim) { model.cancelRecording() }
            bareButton("checkmark", fg: sig) { model.endRecording() }
        }
        .padding(.horizontal, 14)
        .frame(width: FlowBarStyle.ticker.contentSize.width,
               height: FlowBarStyle.ticker.contentSize.height)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color(hex: 0x1A1712)))
    }

    // MARK: - 3d · Proof (underline = refining)

    private func proofContent(_ c: Palette) -> some View {
        VStack(spacing: 0) {
            cardHeader(c, waveWidth: 56)

            wrappedFlow(c, size: 18, underlineInterim: true)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .clipped()
                .mask(topFade)

            cardFooter(c) {
                (Text("underline").underline(true, color: c.sig) + Text(" = refining"))
                    .font(F.mono(10)).tracking(0.6).foregroundStyle(c.ink2)
            }
        }
    }

    // MARK: - Shared card pieces

    private func cardHeader(_ c: Palette, waveWidth: CGFloat) -> some View {
        HStack {
            HStack(spacing: 8) {
                RecDot(color: c.sig)
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
            iconButton("xmark", size: 28, bg: c.paper, fg: c.ink2, border: c.line) { model.cancelRecording() }
            iconButton("checkmark", size: 28, bg: c.sig, fg: .white, border: c.sig) { model.endRecording() }
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
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: k.ticker ? 15 : 17, weight: .semibold))
                .foregroundStyle(k.accent)
            if model.landedCopied {
                (Text("Copied — press ").foregroundColor(k.ink2)
                 + Text("⌘V").foregroundColor(k.ink)
                 + Text(" to paste anywhere").foregroundColor(k.ink2))
                    .font(F.medium(k.ticker ? 13 : 15)).lineLimit(1)
                Spacer(minLength: 6)
            } else {
                (Text("Landed in ").foregroundColor(k.ink2) + Text(app).foregroundColor(k.ink))
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

    /// One line, newest on the right: final words committed, the word being
    /// recognised in the accent color, live caret at the end.
    private func oneLineFlow(font: Font, committed: Color, accent: Color) -> some View {
        let words = model.partialText.split(separator: " ").map(String.init)
        let last = words.last ?? ""
        let head = words.dropLast().joined(separator: " ")
        let headPart = head.isEmpty ? "" : head + " "
        return HStack(spacing: 3) {
            (Text(headPart).foregroundColor(committed) + Text(last).foregroundColor(accent))
                .font(font)
                .lineLimit(1)
                .truncationMode(.head)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Caret(color: accent)
        }
    }

    /// Wrapped editorial flow (Column/Proof): words wrap and rise; the word
    /// being recognised is accented — colored, or underlined in Proof.
    @ViewBuilder
    private func wrappedFlow(_ c: Palette, size: CGFloat, underlineInterim: Bool) -> some View {
        if model.partialText.isEmpty {
            Text("Listening…")
                .font(F.medium(size)).foregroundStyle(c.ink3)
        } else {
            let words = model.partialText.split(separator: " ").map(String.init)
            let last = words.last ?? ""
            let head = words.dropLast().joined(separator: " ")
            let headText = Text(head.isEmpty ? "" : head + " ").foregroundColor(c.ink)
            let interim = underlineInterim
                ? Text(last).foregroundColor(c.ink).underline(true, color: c.sig)
                : Text(last).foregroundColor(c.sig)
            (headText + interim + Text(" ▎").foregroundColor(c.sig))
                .font(F.medium(size))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
    var body: some View {
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
