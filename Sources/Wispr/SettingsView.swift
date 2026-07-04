import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        VStack(spacing: 0) {
            ScreenHeader(model: model, title: "Settings")
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("General")
                        .font(F.extrabold(40)).tracking(-1.4).foregroundStyle(c.ink)
                        .padding(.bottom, 2)

                    card(c) {
                        settingRow("Shortcut", "Hold Right ⌥ to talk · double-tap for hands-free", c) { EmptyView() }
                        divider(c)
                        settingRow("Microphone", "\(model.micName) · built-in preferred", c) { EmptyView() }
                        divider(c)
                        modelRow(c)
                        divider(c)
                        settingRow("Auto-paste", "Insert transcript into the focused app", c) {
                            toggle($model.autoPaste, c)
                        }
                        divider(c)
                        settingRow("Sound cues", "Subtle chimes on start & finish", c) {
                            toggle($model.soundCues, c)
                        }
                        divider(c)
                        settingRow("Launch at login", "Start Wisper automatically", c) {
                            toggle(Binding(get: { model.launchAtLogin },
                                           set: { model.setLaunchAtLogin($0) }), c)
                        }
                    }

                    Text("OVERLAY")
                        .font(F.mono(12)).tracking(1.6).foregroundStyle(c.ink2)

                    card(c) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                ForEach(FlowBarStyle.allCases) { style in
                                    styleCard(style, c)
                                }
                            }
                            HStack {
                                Text(model.flowStyle.blurb)
                                    .font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
                                Spacer()
                                Text("CLICK A STYLE TO SEE IT LIVE ↓")
                                    .font(F.mono(9.5)).tracking(1).foregroundStyle(c.sig)
                            }
                            Divider().overlay(c.line)
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Position").font(F.semibold(14)).foregroundStyle(c.ink)
                                    Text(model.hasCustomOverlayPosition
                                         ? "Custom — drag the bar by its handle to move it"
                                         : "Bottom-center · drag the bar by its handle to move it")
                                        .font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
                                }
                                Spacer()
                                Button { model.resetOverlayPosition() } label: {
                                    Text("RESET")
                                        .font(F.monoSemi(11)).tracking(1)
                                        .foregroundStyle(model.hasCustomOverlayPosition ? c.sig : c.ink3)
                                        .padding(.horizontal, 13).padding(.vertical, 7)
                                        .background(RoundedRectangle(cornerRadius: 7)
                                            .strokeBorder(model.hasCustomOverlayPosition ? c.sig : c.line, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .focusEffectDisabled()
                                .disabled(!model.hasCustomOverlayPosition)
                            }
                        }
                        .padding(.vertical, 16)
                    }

                    Text("FORMATTING")
                        .font(F.mono(12)).tracking(1.6).foregroundStyle(c.ink2)

                    card(c) {
                        settingRow("Clean up text",
                                   "Fix casing, spacing, fillers & stutters · instant, always on", c) {
                            HStack(spacing: 6) {
                                Circle().fill(Color(hex: 0x28C840)).frame(width: 6, height: 6)
                                Text("ON").font(F.mono(10)).tracking(1).foregroundStyle(c.ink2)
                            }
                        }
                        divider(c)
                        settingRow("AI rewrite",
                                   "Optional tone-matched rewrite — slower. \(model.aiStatus.blurb)", c) {
                            toggle($model.aiFormatting, c)
                        }
                        divider(c)
                        settingRow("Style", "How your words get shaped", c) {
                            Picker("", selection: $model.formatMode) {
                                ForEach(FormatMode.allCases) { m in Text(m.label).tag(m) }
                            }
                            .labelsHidden().frame(width: 190).tint(c.ink)
                            .disabled(!model.aiFormatting)
                        }
                        divider(c)
                        settingRow("Remove fillers", "Strip um, uh, you know…", c) {
                            toggle($model.removeFillers, c)
                        }
                        divider(c)
                        settingRow("Voice commands", "“new line”, “new paragraph”, “scratch that”", c) {
                            toggle($model.voiceCommands, c)
                        }
                    }

                    Text("PER-APP STYLE")
                        .font(F.mono(12)).tracking(1.6).foregroundStyle(c.ink2)

                    card(c) { perAppStyles(c) }
                        .opacity(model.aiFormatting ? 1 : 0.55)

                    Text("PERMISSIONS")
                        .font(F.mono(12)).tracking(1.6).foregroundStyle(c.ink2)

                    card(c) {
                        permissionRow("Accessibility", "Required to paste into other apps",
                                      granted: model.accessibilityGranted, c) {
                            model.refreshAccessibility(prompt: true)
                        }
                        divider(c)
                        permissionRow("Microphone", "Required to hear you",
                                      granted: model.micGranted, c) {
                            model.requestMicrophone()
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
                .frame(maxWidth: 640, alignment: .leading)
            }
        }
        .background(c.paper)
    }

    // MARK: - Overlay style cards

    /// One selectable overlay-style card: a tiny schematic of the design
    /// variant (Galley/Column/Ticker/Proof) + its name.
    private func styleCard(_ style: FlowBarStyle, _ c: Palette) -> some View {
        let selected = model.flowStyle == style
        return Button {
            model.flowStyle = style
            model.previewFlowBar()   // show the real bar with sample words
        } label: {
            VStack(spacing: 9) {
                schematic(style, c)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                Text(style.label.uppercased())
                    .font(F.monoSemi(10)).tracking(1.2)
                    .foregroundStyle(selected ? c.sig : c.ink2)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? c.sig.opacity(0.08) : c.paper))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selected ? c.sig : c.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(style.blurb)
    }

    /// Miniature of each overlay look, drawn with primitive shapes.
    @ViewBuilder
    private func schematic(_ style: FlowBarStyle, _ c: Palette) -> some View {
        switch style {
        case .galley:
            // Compact pill: dot · flowing line · confirm block.
            HStack(spacing: 5) {
                Circle().fill(c.sig).frame(width: 5, height: 5)
                Capsule().fill(c.ink3).frame(height: 3)
                RoundedRectangle(cornerRadius: 2.5).fill(c.sig).frame(width: 11, height: 11)
            }
            .padding(.horizontal, 8)
            .frame(width: 82, height: 24)
            .background(RoundedRectangle(cornerRadius: 7).fill(c.panel))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(c.ink.opacity(0.7), lineWidth: 1))
        case .column:
            // Tall editorial card with rising set type.
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    Circle().fill(c.sig).frame(width: 4, height: 4)
                    Capsule().fill(c.line).frame(width: 16, height: 2.5)
                }
                Spacer(minLength: 2)
                Capsule().fill(c.ink3).frame(width: 34, height: 3)
                Capsule().fill(c.ink3).frame(width: 42, height: 3)
                HStack(spacing: 3) {
                    Capsule().fill(c.ink3).frame(width: 20, height: 3)
                    Capsule().fill(c.sig).frame(width: 12, height: 3)
                }
            }
            .padding(7)
            .frame(width: 58, height: 46, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 6).fill(c.panel))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c.ink.opacity(0.7), lineWidth: 1))
        case .ticker:
            // Slim dark tape.
            HStack(spacing: 5) {
                Circle().fill(Color(hex: 0xFF7A4D)).frame(width: 4, height: 4)
                Capsule().fill(Color(hex: 0xE8E1D0).opacity(0.7)).frame(height: 2.5)
                Capsule().fill(Color(hex: 0xFF7A4D)).frame(width: 9, height: 2.5)
            }
            .padding(.horizontal, 8)
            .frame(width: 82, height: 16)
            .background(RoundedRectangle(cornerRadius: 5).fill(Color(hex: 0x1A1712)))
        case .proof:
            // Card where the refining word is underlined.
            VStack(alignment: .leading, spacing: 5) {
                Capsule().fill(c.ink3).frame(width: 40, height: 3)
                HStack(spacing: 3) {
                    Capsule().fill(c.ink3).frame(width: 18, height: 3)
                    VStack(spacing: 2) {
                        Capsule().fill(c.ink3).frame(width: 14, height: 3)
                        Capsule().fill(c.sig).frame(width: 14, height: 2)
                    }
                }
                Capsule().fill(c.ink3).frame(width: 30, height: 3)
            }
            .padding(8)
            .frame(width: 64, height: 42, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 6).fill(c.panel))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c.ink.opacity(0.7), lineWidth: 1))
        }
    }

    // MARK: - Per-app pinned styles

    /// Pin an app to a style: dictations landing there always use that mode,
    /// beating the global Style picker (e.g. Slack → Chat, Xcode → Raw).
    @ViewBuilder
    private func perAppStyles(_ c: Palette) -> some View {
        if model.appStyles.isEmpty {
            settingRow("No pinned apps",
                       "Pin an app so dictation there always uses one style — beats the global Style", c) {
                pinAppMenu(c)
            }
        } else {
            ForEach(model.appStyles) { entry in
                settingRow(entry.appName, entry.bundleID, c) {
                    HStack(spacing: 10) {
                        Picker("", selection: styleBinding(for: entry)) {
                            ForEach(FormatMode.allCases.filter { $0 != .auto }) { m in
                                Text(m.label).tag(m)
                            }
                        }
                        .labelsHidden().frame(width: 170).tint(c.ink)
                        Button {
                            model.appStyles.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(c.ink3)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .help("Unpin \(entry.appName)")
                    }
                }
                divider(c)
            }
            settingRow("Pin another app", "Running apps not yet pinned", c) {
                pinAppMenu(c)
            }
        }
    }

    private func styleBinding(for entry: AppStyleEntry) -> Binding<FormatMode> {
        Binding(
            get: { entry.mode },
            set: { newMode in
                if let i = model.appStyles.firstIndex(where: { $0.id == entry.id }) {
                    model.appStyles[i].mode = newMode
                }
            }
        )
    }

    private func pinAppMenu(_ c: Palette) -> some View {
        Menu {
            ForEach(pinnableApps(), id: \.self) { app in
                Button(app.localizedName ?? "App") {
                    guard let id = app.bundleIdentifier else { return }
                    let mode = FormatMode.resolve(for: app)   // sensible starting pin
                    model.appStyles.append(AppStyleEntry(
                        bundleID: id,
                        appName: app.localizedName ?? id,
                        mode: mode == .auto ? .document : mode
                    ))
                }
            }
        } label: {
            Text("PIN APP…")
                .font(F.monoSemi(11)).tracking(1).foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 7).fill(c.sig))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Regular (Dock-visible) running apps that aren't Wispr and aren't pinned yet.
    private func pinnableApps() -> [NSRunningApplication] {
        let pinned = Set(model.appStyles.map(\.bundleID))
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.processIdentifier != NSRunningApplication.current.processIdentifier }
            .filter { app in app.bundleIdentifier.map { !pinned.contains($0) } ?? false }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func modelRow(_ c: Palette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Model").font(F.semibold(15)).foregroundStyle(c.ink)
                Text("On-device Whisper · downloads once, runs offline")
                    .font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
            }
            HStack(spacing: 10) {
                ForEach(ModelCatalog.all) { m in
                    modelCard(m, c)
                }
            }
            Text(ModelCatalog.info(model.modelName).note)
                .font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
            if let p = model.downloadProgress {
                HStack(spacing: 10) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(c.line)
                            Capsule().fill(c.sig).frame(width: geo.size.width * max(0.02, p))
                        }
                    }.frame(height: 4)
                    Text("\(Int(p * 100))%").font(F.monoSemi(11)).foregroundStyle(c.sig)
                }
            } else {
                HStack(spacing: 6) {
                    Circle().fill(model.modelReady ? Color(hex: 0x28C840) : c.ink3).frame(width: 6, height: 6)
                    Text(model.modelReady ? "READY · RUNS OFFLINE" : "NOT LOADED")
                        .font(F.mono(10)).tracking(1).foregroundStyle(c.ink2)
                }
            }
        }
        .padding(.vertical, 15)
    }

    /// One selectable model card, matching the overlay-style cards: a small
    /// weight schematic + size on top, the name below. Replaces the old dropdown.
    private func modelCard(_ m: WhisperModelInfo, _ c: Palette) -> some View {
        let selected = model.modelName == m.id
        let weight = (ModelCatalog.all.firstIndex { $0.id == m.id } ?? 0) + 1
        return Button { model.reloadModel(m.id) } label: {
            VStack(spacing: 9) {
                VStack(spacing: 7) {
                    HStack(alignment: .bottom, spacing: 3) {
                        ForEach(0..<ModelCatalog.all.count, id: \.self) { i in
                            Capsule()
                                .fill(i < weight ? c.sig : c.line)
                                .frame(width: 5, height: 9 + CGFloat(i) * 6)
                        }
                    }
                    Text(m.size)
                        .font(F.mono(9)).tracking(0.6)
                        .foregroundStyle(selected ? c.sig : c.ink2)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                Text(m.name.uppercased())
                    .font(F.monoSemi(10)).tracking(1.2)
                    .foregroundStyle(selected ? c.sig : c.ink2)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? c.sig.opacity(0.08) : c.paper))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selected ? c.sig : c.line, lineWidth: selected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .disabled(model.downloadProgress != nil)   // don't switch mid-download
        .help("\(m.note) · \(m.size)")
    }

    private func card<Content: View>(_ c: Palette, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(c.panel)
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(c.line))
            )
    }

    private func divider(_ c: Palette) -> some View {
        Rectangle().fill(c.line).frame(height: 1)
    }

    private func toggle(_ binding: Binding<Bool>, _ c: Palette) -> some View {
        Toggle("", isOn: binding).labelsHidden().toggleStyle(.switch).tint(c.sig)
    }

    private func settingRow<Control: View>(_ title: String, _ subtitle: String, _ c: Palette,
                                           @ViewBuilder control: () -> Control) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(F.semibold(15)).foregroundStyle(c.ink)
                Text(subtitle).font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
            }
            Spacer()
            control()
        }
        .padding(.vertical, 15)
    }

    private func permissionRow(_ title: String, _ subtitle: String, granted: Bool, _ c: Palette,
                               action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(F.semibold(15)).foregroundStyle(c.ink)
                Text(subtitle).font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
            }
            Spacer()
            if granted {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: 0x28C840)).frame(width: 7, height: 7)
                    Text("GRANTED").font(F.mono(11)).tracking(1).foregroundStyle(c.ink2)
                }
            } else {
                Button(action: action) {
                    Text("GRANT").font(F.monoSemi(11)).tracking(1).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 7).fill(c.sig))
                }.buttonStyle(.plain)
            }
        }
        .padding(.vertical, 15)
    }
}

/// Styled "coming soon" screen for nav items not yet built.
struct PlaceholderView: View {
    @ObservedObject var model: AppModel
    var screen: Screen
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        VStack(spacing: 0) {
            ScreenHeader(model: model, title: screen.title)
            VStack(alignment: .leading, spacing: 14) {
                Eyebrow(text: "COMING SOON", color: c.sig)
                Text(screen.title)
                    .font(F.extrabold(52)).tracking(-1.8).foregroundStyle(c.ink)
                Text(screen.blurb)
                    .font(F.regular(17)).foregroundStyle(c.ink2)
                    .frame(maxWidth: 420, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(40)
        }
        .background(c.paper)
    }
}
