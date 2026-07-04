import SwiftUI

struct HomeView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        VStack(spacing: 0) {
            ScreenHeader(model: model, title: "Home")
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !model.accessibilityGranted || !model.micGranted {
                        permissionBanner(c)
                    }
                    heroBlock(c)
                    spectrogram(c)
                    HStack(alignment: .top, spacing: 28) {
                        recentDictations(c)
                        todayCard(c)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
            }
        }
        .background(c.paper)
    }

    // MARK: - Permission banner (only while something's missing)

    /// Front-and-center warning so a returning user (or one who revoked a grant)
    /// sees immediately why dictation won't work — and can fix it in one click.
    /// Auto-hides the instant both grants land (the permission poller updates it).
    private func permissionBanner(_ c: Palette) -> some View {
        let needsMic = !model.micGranted
        let needsAcc = !model.accessibilityGranted
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(c.sig)
                Text("FINISH SETUP").font(F.mono(11)).tracking(1.6).foregroundStyle(c.sig)
                Spacer()
                Text("Dictation is off until these are granted")
                    .font(F.mono(10)).tracking(0.4).foregroundStyle(c.ink3)
            }
            .padding(.bottom, 12)

            if needsMic {
                permRow("Microphone", "Required to hear you", last: !needsAcc, c) {
                    model.requestMicrophone()
                }
            }
            if needsAcc {
                permRow("Accessibility", "Required to paste into your apps", last: true, c) {
                    model.refreshAccessibility(prompt: true)
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))
        .background(
            RoundedRectangle(cornerRadius: 8).fill(c.sig.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(c.sig.opacity(0.55)))
        )
    }

    private func permRow(_ title: String, _ subtitle: String, last: Bool, _ c: Palette,
                         action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(F.semibold(15)).foregroundStyle(c.ink)
                    Text(subtitle).font(F.mono(11)).tracking(0.4).foregroundStyle(c.ink3)
                }
                Spacer()
                Button(action: action) {
                    Text("GRANT").font(F.monoSemi(11)).tracking(1).foregroundStyle(.white)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 7).fill(c.sig))
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
            }
            .padding(.vertical, 11)
            if !last { Rectangle().fill(c.sig.opacity(0.2)).frame(height: 1) }
        }
    }

    // MARK: - Hero

    private func heroBlock(_ c: Palette) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Eyebrow(text: "PUSH-TO-TALK DICTATION", color: c.sig)
                Text(model.isRecording ? "Listening…" : "Ready when you are.")
                    .font(F.extrabold(22))
                    .tracking(-0.6)
                    .foregroundStyle(c.ink)
            }
            Spacer()
            Button { model.toggleRecording() } label: {
                VStack(alignment: .trailing, spacing: 8) {
                    KeyCap(label: model.isRecording ? "Recording…  ■" : "Hold  Right ⌥",
                           active: model.isRecording, c: c)
                    Text("HOLD TO TALK — ANY APP")
                        .font(F.mono(10)).tracking(1.6).foregroundStyle(c.ink3)
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.canRecord)
            .opacity(model.canRecord ? 1 : 0.5)
        }
    }

    // MARK: - Spectrogram

    private func spectrogram(_ c: Palette) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text(model.isRecording ? "● LIVE INPUT" : "● INPUT")
                    .font(F.mono(10)).tracking(1.2).foregroundStyle(c.sig)
                Spacer()
                Text("16 kHz · MONO")
                    .font(F.mono(10)).tracking(1.2).foregroundStyle(c.ink3)
            }
            Group {
                if model.isRecording {
                    WaveformView(levels: model.levels, color: c.ink, barWidth: 3)
                } else {
                    IdleWaveform(color: c.ink3, barWidth: 3)
                }
            }
            .frame(height: 100)
            HStack {
                ForEach(["0s", "10s", "20s", "30s"], id: \.self) { t in
                    Text(t).font(F.mono(10)).tracking(1).foregroundStyle(c.ink3)
                    if t != "30s" { Spacer() }
                }
            }

            // Live partial transcript — words appear as you speak.
            if model.isRecording && !model.partialText.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Text("❯").font(F.mono(13)).foregroundStyle(c.sig)
                    Text(model.partialText)
                        .font(F.medium(15)).foregroundStyle(c.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 4)
            }

            // Model download progress.
            if let p = model.downloadProgress {
                VStack(spacing: 6) {
                    HStack {
                        Text("DOWNLOADING \(ModelCatalog.info(model.modelName).name.uppercased()) MODEL")
                            .font(F.mono(10)).tracking(1.2).foregroundStyle(c.ink2)
                        Spacer()
                        Text("\(Int(p * 100))%").font(F.monoSemi(10)).foregroundStyle(c.sig)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(c.line)
                            Capsule().fill(c.sig).frame(width: geo.size.width * max(0.02, p))
                        }
                    }.frame(height: 4)
                }
                .padding(.top, 6)
            }
        }
        .padding(EdgeInsets(top: 16, leading: 24, bottom: 15, trailing: 24))
        .background(
            RoundedRectangle(cornerRadius: 6).fill(c.panel)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c.line))
        )
    }

    // MARK: - Recent dictations

    private func recentDictations(_ c: Palette) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RECENT DICTATIONS").font(F.mono(12)).tracking(1.6).foregroundStyle(c.ink2)
                Spacer()
                Button { model.nav = .history } label: {
                    Text("VIEW ALL →").font(F.mono(11)).tracking(1).foregroundStyle(c.sig)
                }.buttonStyle(.plain)
            }
            .padding(.bottom, 6)

            if model.history.isEmpty {
                Text("Nothing yet — hold Right ⌥ and speak.")
                    .font(F.regular(15)).foregroundStyle(c.ink3)
                    .padding(.vertical, 18)
            } else {
                ForEach(Array(model.history.prefix(3).enumerated()), id: \.element.id) { index, item in
                    dictationRow(index: index, item: item, c: c,
                                 last: index == min(2, model.history.count - 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dictationRow(index: Int, item: Dictation, c: Palette, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 20) {
            Text(String(format: "%02d", index + 1))
                .font(F.monoSemi(13)).foregroundStyle(c.sig).padding(.top, 3)
            VStack(alignment: .leading, spacing: 8) {
                Text(item.text)
                    .font(F.medium(16)).foregroundStyle(c.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(metaLine(item))
                    .font(F.mono(10.5)).tracking(1).foregroundStyle(c.ink3)
            }
            HStack(spacing: 2) {
                rowIcon("doc.on.doc", c) { model.copyTranscript(item.text) }
                rowIcon("return", c) { model.reinsert(item.text) }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 15)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(c.line).frame(height: 1) }
        }
    }

    private func rowIcon(_ symbol: String, _ c: Palette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14))
                .foregroundStyle(c.ink3)
                .frame(width: 30, height: 30)
        }.buttonStyle(.plain)
    }

    private func metaLine(_ item: Dictation) -> String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        var line = "\(f.string(from: item.date).uppercased()) · \(item.wordCount) WORDS · \(Int(item.duration))s"
        if item.latency > 0 {
            line += String(format: " · ⚡%.1fs", item.latency)   // stop → text on screen
        }
        return line
    }

    // MARK: - Today card

    private func todayCard(_ c: Palette) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("TODAY").font(F.mono(12)).tracking(1.6).foregroundStyle(c.ink2)
                Spacer()
                Text("● LIVE").font(F.mono(10)).tracking(1).foregroundStyle(c.sig)
            }
            stat("WORDS", "\(model.wordsToday)", model.wordsFraction, c)
            stat("SPEED · WPM", model.averageWPM > 0 ? "\(model.averageWPM)" : "—", model.wpmFraction, c)
            stat("TIME SAVED", model.timeSavedString, model.timeSavedFraction, c)
            stat("STREAK · DAYS", "\(model.streakDays)", model.streakFraction, c)
        }
        .padding(EdgeInsets(top: 20, leading: 20, bottom: 18, trailing: 20))
        .frame(width: 290)
        .background(
            RoundedRectangle(cornerRadius: 6).fill(c.panel)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c.line))
        )
    }

    private func stat(_ label: String, _ value: String, _ fraction: Double, _ c: Palette) -> some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(label).font(F.mono(11)).tracking(0.6).foregroundStyle(c.ink2)
                Spacer()
                Text(value).font(F.extrabold(20)).tracking(-0.4).foregroundStyle(c.ink)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(c.line)
                    Capsule().fill(c.sig).frame(width: geo.size.width * max(0.02, min(1, fraction)))
                }
            }
            .frame(height: 4)
        }
    }
}
