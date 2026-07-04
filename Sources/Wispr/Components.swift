import SwiftUI

/// The mono top bar used across screens: label — date · search · status · avatar.
struct ScreenHeader: View {
    @ObservedObject var model: AppModel
    var title: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        HStack {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(F.mono(12)).tracking(1.6).foregroundStyle(c.ink2)
                Text("— \(Self.dateString)")
                    .font(F.mono(12)).tracking(1.6).foregroundStyle(c.ink3)
            }
            Spacer()
            HStack(spacing: 20) {
                HStack(spacing: 7) {
                    Circle().fill(statusColor(c)).frame(width: 6, height: 6)
                    Text(badgeText.uppercased())
                        .font(F.mono(11)).tracking(1)
                        .foregroundStyle(showSetupWarning ? c.sig : c.ink2)
                }
                Text("A")
                    .font(F.bold(13)).foregroundStyle(c.ink)
                    .frame(width: 30, height: 30)
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(c.ink, lineWidth: 1))
            }
        }
        .padding(.horizontal, 30)
        .frame(height: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(c.line).frame(height: 1) }
    }

    /// When idle but a permission is missing, the badge warns instead of lying
    /// "Ready" — dictation can't actually work yet.
    private var showSetupWarning: Bool {
        if case .idle = model.state {
            return !(model.accessibilityGranted && model.micGranted)
        }
        return false
    }

    private var badgeText: String {
        showSetupWarning ? "Setup" : model.statusText
    }

    private func statusColor(_ c: Palette) -> Color {
        if showSetupWarning { return c.sig }
        switch model.state {
        case .recording, .transcribing: return c.sig
        case .error: return Color(hex: 0xE5401B)
        default: return Color(hex: 0x28C840)
        }
    }

    static var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: Date()).uppercased()
    }
}

/// A keyboard cap with the design's hard 3px drop.
struct KeyCap: View {
    var label: String
    var active: Bool
    var c: Palette

    var body: some View {
        Text(label)
            .font(F.monoMed(15))
            .foregroundStyle(active ? .white : c.ink)
            .padding(.horizontal, 16)
            .frame(height: 46)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(c.ink).offset(y: 3)
                    RoundedRectangle(cornerRadius: 8).fill(active ? c.sig : c.panel)
                    RoundedRectangle(cornerRadius: 8).strokeBorder(c.ink, lineWidth: 1)
                }
            )
    }
}

/// Small section eyebrow in mono.
struct Eyebrow: View {
    var text: String
    var color: Color
    var body: some View {
        Text(text).font(F.mono(11)).tracking(1.8).foregroundStyle(color)
    }
}
