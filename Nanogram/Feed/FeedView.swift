import SwiftUI

/// The feed screen: a loading screen or an error screen while the first page loads,
/// and then the scrolling games.
struct FeedView: View {
    let viewModel: any FeedViewModelProtocol
    let gameViewSettings: GameViewSettings

    /// Whether the app is in use, in the background, or covered (for example by Control Center).
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch viewModel.state {
            case .loadingFirstPage:
                FeedLoadingView()
            case .failedInitial(let error):
                FeedErrorView(error: error, retry: viewModel.retry)
            case .loaded:
                GameScrollView(viewModel: viewModel, gameViewSettings: gameViewSettings)
                    .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .task { viewModel.start() }
        .onChange(of: scenePhase) { _, newPhase in
            appPhaseChanged(to: newPhase)
        }
    }

    /// No game runs or makes a sound unless the app is on screen and in use.
    private func appPhaseChanged(to phase: ScenePhase) {
        if phase == .active {
            viewModel.appBecameActive()
        } else {
            viewModel.appBecameInactive()
        }
    }
}
