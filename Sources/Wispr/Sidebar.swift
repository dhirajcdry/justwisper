import SwiftUI

/// The sidebar — a compact icon rail. One view, no expand/collapse.
struct Sidebar: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    private let items: [(title: String, icon: String, screen: Screen)] = [
        ("Home",       "house",                   .home),
        ("History",    "clock.arrow.circlepath",  .history),
        ("Insights",   "chart.bar",               .insights),
        ("Dictionary", "character.book.closed",   .dictionary),
        ("Snippets",   "note.text",               .snippets),
    ]

    var body: some View {
        let c = Palette.current(scheme)
        VStack(spacing: 0) {
            // Space for the native traffic lights (window uses a hidden title bar).
            Color.clear.frame(height: 30)

            // Brand mark — click to jump Home.
            Button { model.nav = .home } label: {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 10).fill(c.ink)
                        .frame(width: 40, height: 40)
                    Text("W").font(F.extrabold(19)).foregroundStyle(c.paper)
                        .frame(width: 40, height: 40)
                    Circle().fill(c.sig).frame(width: 6, height: 6).padding(5)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusEffectDisabled()
            .help("justwisper — Home")
            .padding(.bottom, 20)

            ForEach(items, id: \.screen) { item in
                railItem(item.icon, item.title, active: model.nav == item.screen, c) {
                    model.nav = item.screen
                }
            }

            Spacer(minLength: 12)

            Rectangle().fill(c.line).frame(height: 1).padding(.horizontal, 14).padding(.bottom, 10)

            railItem("gearshape", "Settings", active: model.nav == .settings, c) { model.nav = .settings }
            railItem("questionmark.circle", "Help", active: false, c) {
                NSWorkspace.shared.open(URL(string: "https://github.com/dhirajcdry/justwisper/blob/main/docs/TROUBLESHOOTING.md")!)
            }

            Circle().fill(Color(hex: 0x28C840)).frame(width: 6, height: 6)
                .padding(.top, 12)
                .help("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev") · on-device")
        }
        .padding(.bottom, 20)
        .frame(width: 72)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(c.paper)
        .overlay(alignment: .trailing) { Rectangle().fill(c.line).frame(width: 1) }
    }

    private func railItem(_ symbol: String, _ title: String, active: Bool, _ c: Palette,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: active ? .semibold : .regular))
                    .foregroundStyle(active ? c.sig : c.ink2)
                    .frame(height: 20)
                Text(title)
                    .font(F.medium(9)).tracking(0.2)
                    .foregroundStyle(active ? c.ink : c.ink3)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 9)
                    .fill(active ? c.sig.opacity(0.10) : .clear)
            )
            .overlay(alignment: .leading) {
                Rectangle().fill(c.sig)
                    .frame(width: 3, height: 18)
                    .opacity(active ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(title)
        .padding(.horizontal, 10)
    }
}
