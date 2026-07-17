import SwiftUI

@main
@MainActor
struct ScrollDirectionApp: App {
    @State private var appState: AppState

    init() {
        let appState = AppState.live()
        appState.startAtLaunch()
        _appState = State(initialValue: appState)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            Image(systemName: appState.status.systemImage)
                .accessibilityLabel("ScrollDirection")
        }
        .menuBarExtraStyle(.menu)
    }
}
