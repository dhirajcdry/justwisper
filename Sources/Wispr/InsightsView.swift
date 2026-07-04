import SwiftUI

/// Local analytics over the persisted dictation history. Everything on this
/// screen is computed on-device from history.json — nothing leaves the Mac.
struct InsightsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var confirmErase = false

    var body: some View {
        let c = Palette.current(scheme)
        VStack(spacing: 0) {
            ScreenHeader(model: model, title: "Insights")
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    hero(c)
                    statRow(c)
                    chartCard(c)
                    HStack(alignment: .top, spacing: 24) {
                        topAppsCard(c)
                        recordsCard(c)
                    }
                    privacyCard(c)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
            }
        }
        .background(c.paper)
    }

    // MARK: - Hero

    private func hero(_ c: Palette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow(text: "INSIGHTS — COMPUTED ON THIS MAC", color: c.sig)
            Text("Your voice,\nby the numbers.")
                .font(F.extrabold(40)).tracking(-1.4).lineSpacing(-4)
                .foregroundStyle(c.ink)
        }
    }

    // MARK: - Headline stats

    private func statRow(_ c: Palette) -> some View {
        HStack(spacing: 16) {
            statTile("TOTAL WORDS", format(model.totalWords), c)
            statTile("DICTATIONS", format(model.history.count), c)
            statTile("AVG SPEED", model.averageWPM > 0 ? "\(model.averageWPM) wpm" : "—", c)
            statTile("TIME SAVED", model.timeSavedString, c)
        }
    }

    private func statTile(_ label: String, _ value: String, _ c: Palette) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(F.mono(10)).tracking(1.4).foregroundStyle(c.ink2)
            Text(value).font(F.extrabold(28)).tracking(-0.8).foregroundStyle(c.ink)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(EdgeInsets(top: 16, leading: 18, bottom: 14, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6).fill(c.panel)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c.line))
        )
    }

    // MARK: - 14-day chart

    /// Words per day for the last 14 days, oldest first.
    private var dailyWords: [(day: Date, words: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var byDay: [Date: Int] = [:]
        for item in model.history {
            byDay[cal.startOfDay(for: item.date), default: 0] += item.wordCount
        }
        return (0..<14).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (day, byDay[day] ?? 0)
        }
    }

    private func chartCard(_ c: Palette) -> some View {
        let days = dailyWords
        let peak = max(1, days.map(\.words).max() ?? 1)
        let cal = Calendar.current
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("WORDS · LAST 14 DAYS").font(F.mono(11)).tracking(1.6).foregroundStyle(c.ink2)
                Spacer()
                Text("PEAK \(format(peak == 1 && days.allSatisfy { $0.words == 0 } ? 0 : peak))")
                    .font(F.mono(10)).tracking(1).foregroundStyle(c.sig)
            }
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(days, id: \.day) { entry in
                    let isToday = cal.isDateInToday(entry.day)
                    VStack(spacing: 7) {
                        Capsule()
                            .fill(isToday ? c.sig : (entry.words > 0 ? c.ink.opacity(0.55) : c.line))
                            .frame(height: max(4, 96 * CGFloat(entry.words) / CGFloat(peak)))
                            .frame(maxHeight: 96, alignment: .bottom)
                            .help("\(format(entry.words)) words")
                        Text(dayLetter(entry.day))
                            .font(F.mono(9)).foregroundStyle(isToday ? c.sig : c.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 22, bottom: 14, trailing: 22))
        .background(
            RoundedRectangle(cornerRadius: 6).fill(c.panel)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c.line))
        )
    }

    private func dayLetter(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEEE"
        return f.string(from: date).uppercased()
    }

    // MARK: - Top apps

    /// Words dictated per destination app, largest first.
    private var topApps: [(name: String, words: Int)] {
        var byApp: [String: Int] = [:]
        for item in model.history {
            byApp[item.appName ?? "Elsewhere", default: 0] += item.wordCount
        }
        return byApp.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }.prefix(5).map { $0 }
    }

    private func topAppsCard(_ c: Palette) -> some View {
        let apps = topApps
        let peak = max(1, apps.first?.words ?? 1)
        return VStack(alignment: .leading, spacing: 14) {
            Text("WHERE YOU DICTATE").font(F.mono(11)).tracking(1.6).foregroundStyle(c.ink2)
            if apps.isEmpty {
                Text("Dictate into a few apps and they'll rank here.")
                    .font(F.regular(14)).foregroundStyle(c.ink3)
                    .padding(.vertical, 8)
            } else {
                ForEach(Array(apps.enumerated()), id: \.element.name) { index, app in
                    VStack(spacing: 7) {
                        HStack {
                            Text(String(format: "%02d", index + 1))
                                .font(F.monoSemi(11)).foregroundStyle(c.sig)
                            Text(app.name).font(F.semibold(14)).foregroundStyle(c.ink)
                            Spacer()
                            Text("\(format(app.words)) WORDS")
                                .font(F.mono(10)).tracking(0.8).foregroundStyle(c.ink3)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(c.line)
                                Capsule().fill(index == 0 ? c.sig : c.ink.opacity(0.45))
                                    .frame(width: geo.size.width * CGFloat(app.words) / CGFloat(peak))
                            }
                        }
                        .frame(height: 4)
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 18, trailing: 20))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6).fill(c.panel)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c.line))
        )
    }

    // MARK: - Records

    private func recordsCard(_ c: Palette) -> some View {
        let best = dailyBest
        let longest = model.history.map(\.duration).max() ?? 0
        let fastest = model.history.filter { $0.latency > 0 }.map(\.latency).min()
        return VStack(alignment: .leading, spacing: 0) {
            Text("RECORDS").font(F.mono(11)).tracking(1.6).foregroundStyle(c.ink2)
                .padding(.bottom, 6)
            recordRow("Current streak", model.streakDays == 1 ? "1 day" : "\(model.streakDays) days", c)
            recordRow("Best day", best.words > 0 ? "\(format(best.words)) words" : "—", c)
            recordRow("Longest take", longest > 0 ? clock(longest) : "—", c)
            recordRow("Fastest result", fastest.map { String(format: "⚡%.1fs", $0) } ?? "—", c, last: true)
        }
        .padding(EdgeInsets(top: 16, leading: 20, bottom: 10, trailing: 20))
        .frame(width: 280, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6).fill(c.panel)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c.line))
        )
    }

    private func recordRow(_ label: String, _ value: String, _ c: Palette, last: Bool = false) -> some View {
        HStack {
            Text(label).font(F.regular(13.5)).foregroundStyle(c.ink2)
            Spacer()
            Text(value).font(F.monoSemi(13)).foregroundStyle(c.ink)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(c.line).frame(height: 1) }
        }
    }

    private var dailyBest: (day: Date?, words: Int) {
        let cal = Calendar.current
        var byDay: [Date: Int] = [:]
        for item in model.history {
            byDay[cal.startOfDay(for: item.date), default: 0] += item.wordCount
        }
        let best = byDay.max { $0.value < $1.value }
        return (best?.key, best?.value ?? 0)
    }

    // MARK: - Privacy

    private func privacyCard(_ c: Palette) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 16, weight: .semibold)).foregroundStyle(c.sig)
            VStack(alignment: .leading, spacing: 3) {
                Text("Private by design").font(F.semibold(14)).foregroundStyle(c.ink)
                Text("History lives in Application Support on this Mac. No cloud, no sync, no telemetry.")
                    .font(F.mono(10.5)).tracking(0.3).foregroundStyle(c.ink3)
            }
            Spacer()
            Button { confirmErase = true } label: {
                Text("ERASE HISTORY")
                    .font(F.monoSemi(10.5)).tracking(1).foregroundStyle(c.sig)
                    .padding(.horizontal, 13).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 7).strokeBorder(c.sig, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
        }
        .padding(EdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 16))
        .background(
            RoundedRectangle(cornerRadius: 6).fill(c.panel)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(c.line))
        )
        .confirmationDialog("Erase all stored dictations?",
                            isPresented: $confirmErase, titleVisibility: .visible) {
            Button("Erase \(model.history.count) dictations", role: .destructive) {
                model.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deletes history.json from this Mac. This can't be undone.")
        }
    }

    // MARK: - Formatting helpers

    private func format(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    private func clock(_ seconds: Double) -> String {
        let s = Int(seconds)
        return s >= 60 ? String(format: "%d:%02d min", s / 60, s % 60) : "\(s)s"
    }
}
