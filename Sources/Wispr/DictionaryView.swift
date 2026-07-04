import SwiftUI

/// Shared "Press"-styled building blocks for the Dictionary & Snippets editors.
enum EditorUI {
    static func card<Content: View>(_ c: Palette, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: 8).fill(c.panel)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(c.line)))
    }

    static func divider(_ c: Palette) -> some View { Rectangle().fill(c.line).frame(height: 1) }

    static func addButton(_ c: Palette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                Text("ADD").font(F.monoSemi(11)).tracking(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 7).fill(c.sig))
        }.buttonStyle(.plain)
    }

    static func deleteButton(_ c: Palette, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "trash").font(.system(size: 12, weight: .medium)).foregroundStyle(c.ink3)
                .frame(width: 32, height: 32)
        }.buttonStyle(.plain)
    }

    static func emptyState(_ title: String, _ subtitle: String, _ c: Palette) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(F.semibold(16)).foregroundStyle(c.ink)
            Text(subtitle).font(F.regular(14)).foregroundStyle(c.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .background(RoundedRectangle(cornerRadius: 8).fill(c.panel.opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(c.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))))
    }

    static func plainField(_ text: Binding<String>, placeholder: String, c: Palette) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(F.mono(13)).foregroundStyle(c.ink)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 7).fill(c.paper)
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(c.line)))
            .frame(maxWidth: .infinity)
    }
}

/// Custom vocabulary editor: teach Wispr how heard terms should be written.
struct DictionaryView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        VStack(spacing: 0) {
            ScreenHeader(model: model, title: "Dictionary")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: "CUSTOM VOCABULARY", color: c.sig)
                            Text("Dictionary")
                                .font(F.extrabold(40)).tracking(-1.4).foregroundStyle(c.ink)
                        }
                        Spacer()
                        EditorUI.addButton(c) {
                            model.vocab.insert(VocabEntry(spoken: "", written: ""), at: 0)
                        }
                    }
                    Text("Names, jargon, and spellings Whisper gets wrong. Each entry rewrites the spoken form on the left to the exact text on the right — before it's pasted.")
                        .font(F.regular(14)).foregroundStyle(c.ink2)
                        .frame(maxWidth: 560, alignment: .leading)

                    if model.vocab.isEmpty {
                        EditorUI.emptyState("No terms yet", "Add your name, company, or any word that comes out wrong.", c)
                    } else {
                        EditorUI.card(c) {
                            HStack {
                                Text("HEARD AS").font(F.mono(10)).tracking(1.4).foregroundStyle(c.ink3)
                                Spacer()
                                Text("WRITTEN AS").font(F.mono(10)).tracking(1.4).foregroundStyle(c.ink3)
                            }.padding(.vertical, 10)
                            EditorUI.divider(c)
                            ForEach($model.vocab) { $entry in
                                row($entry, c) { model.vocab.removeAll { $0.id == entry.id } }
                                if entry.id != model.vocab.last?.id { EditorUI.divider(c) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 26)
                .frame(maxWidth: 720, alignment: .leading)
            }
        }
        .background(c.paper)
    }

    private func row(_ entry: Binding<VocabEntry>, _ c: Palette, onDelete: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            EditorUI.plainField(entry.spoken, placeholder: "e.g. get new resume", c: c)
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .bold)).foregroundStyle(c.ink3)
            EditorUI.plainField(entry.written, placeholder: "e.g. GetNewResume", c: c)
            EditorUI.deleteButton(c, action: onDelete)
        }
        .padding(.vertical, 10)
    }
}
