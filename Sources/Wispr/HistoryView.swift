import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        VStack(spacing: 0) {
            ScreenHeader(model: model, title: "History")
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .bottom) {
                        Text("Every word\nyou've spoken.")
                            .font(F.extrabold(40)).tracking(-1.4).lineSpacing(-4)
                            .foregroundStyle(c.ink)
                        Spacer()
                        Text("\(model.history.count) TOTAL")
                            .font(F.mono(11)).tracking(1.4).foregroundStyle(c.ink3)
                    }
                    .padding(.bottom, 24)

                    if model.history.isEmpty {
                        Text("No dictations yet. Hold Right ⌥ anywhere and speak.")
                            .font(F.regular(16)).foregroundStyle(c.ink3)
                            .padding(.vertical, 30)
                    } else {
                        ForEach(Array(model.history.enumerated()), id: \.element.id) { index, item in
                            row(index: index, item: item, c: c,
                                last: index == model.history.count - 1)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
            }
        }
        .background(c.paper)
    }

    private func row(index: Int, item: Dictation, c: Palette, last: Bool) -> some View {
        HStack(alignment: .top, spacing: 20) {
            Text(String(format: "%02d", index + 1))
                .font(F.monoSemi(13)).foregroundStyle(c.sig).padding(.top, 3)
            VStack(alignment: .leading, spacing: 8) {
                Text(item.text)
                    .font(F.medium(16.5)).foregroundStyle(c.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(meta(item))
                    .font(F.mono(10.5)).tracking(1).foregroundStyle(c.ink3)
            }
            HStack(spacing: 2) {
                icon("doc.on.doc", c) { model.copyTranscript(item.text) }
                icon("return", c) { model.reinsert(item.text) }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 16)
        .overlay(alignment: .bottom) {
            if !last { Rectangle().fill(c.line).frame(height: 1) }
        }
    }

    private func icon(_ symbol: String, _ c: Palette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14)).foregroundStyle(c.ink3)
                .frame(width: 30, height: 30)
        }.buttonStyle(.plain)
    }

    private func meta(_ item: Dictation) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE h:mm a"
        var line = "\(f.string(from: item.date).uppercased()) · \(item.wordCount) WORDS · \(Int(item.duration))s"
        if let app = item.appName { line += " · → \(app.uppercased())" }
        return line
    }
}
