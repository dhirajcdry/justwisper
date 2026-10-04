import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let c = Palette.current(scheme)
        ZStack {
            HStack(spacing: 0) {
                Sidebar(model: model)
                Group {
                    switch model.nav {
                    case .home: HomeView(model: model)
                    case .history: HistoryView(model: model)
                    case .insights: InsightsView(model: model)
                    case .dictionary: DictionaryView(model: model)
                    case .snippets: SnippetsView(model: model)
                    case .settings: SettingsView(model: model)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !model.hasOnboarded {
                OnboardingView(model: model)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.hasOnboarded)
        .background(c.paper)
        .frame(minWidth: 820, minHeight: 640)
        .focusEffectDisabled()
        .onAppear { model.start() }
    }
}
