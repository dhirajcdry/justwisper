import SwiftUI

/// Snippet editor: say a trigger phrase, expand it into longer canonical text.
struct SnippetsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        VStack(spacing: 0) {
            ScreenHeader(model: model, title: "Snippets")
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            Eyebrow(text: "TEXT EXPANSION", color: c.sig)
                            Text("Snippets")
                                .font(F.extrabold(40)).tracking(-1.4).foregroundStyle(c.ink)
                        }
                        Spacer()
                        EditorUI.addButton(c) {
                            model.snippets.insert(SnippetEntry(trigger: "", expansion: ""), at: 0)
                        }
                    }
                    Text("Say a short trigger and Wispr expands it into the full text — signatures, addresses, boilerplate. Expansions can span multiple lines.")
                        .font(F.regular(14)).foregroundStyle(c.ink2)
                        .frame(maxWidth: 560, alignment: .leading)

                    if model.snippets.isEmpty {
                        EditorUI.emptyState("No snippets yet", "Try a trigger like \u{201C}my signature\u{201D} that expands to your sign-off.", c)
                    } else {
                        ForEach($model.snippets) { $entry in
                            snippetCard($entry, c) { model.snippets.removeAll { $0.id == entry.id } }
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

    private func snippetCard(_ entry: Binding<SnippetEntry>, _ c: Palette,
                             onDelete: @escaping () -> Void) -> some View {
        EditorUI.card(c) {
            HStack(spacing: 10) {
                Text("TRIGGER").font(F.mono(10)).tracking(1.4).foregroundStyle(c.ink3)
                TextField("say this…", text: entry.trigger)
                    .textFieldStyle(.plain).font(F.monoSemi(13)).foregroundStyle(c.sig)
                Spacer()
                EditorUI.deleteButton(c, action: onDelete)
            }
            .padding(.vertical, 10)
            EditorUI.divider(c)
            HStack(alignment: .top, spacing: 10) {
                Text("EXPANDS")
                    .font(F.mono(10)).tracking(1.4).foregroundStyle(c.ink3)
                    .padding(.top, 4)
                TextEditor(text: entry.expansion)
                    .font(F.regular(14)).foregroundStyle(c.ink)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 64)
            }
            .padding(.vertical, 10)
        }
    }
}
