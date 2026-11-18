import SwiftUI

/// Puts the UIKit game scroll inside SwiftUI and connects it to the feed's view model.
/// This is the only place that knows both of them.
///
/// It also builds the UIKit screen: it is the one place that creates the concrete runner
/// factory, game views, overlays and Close button. The screen itself only sees their protocols.
struct GameScrollView: UIViewControllerRepresentable {
    let viewModel: any FeedViewModelProtocol
    let gameViewSettings: GameViewSettings

    func makeUIViewController(context: Context) -> GameScrollViewController {
        let runnerFactory = GameRunnerFactory(settings: gameViewSettings)

        var gameViews: [any GameViewProtocol] = []
        for _ in 0..<PositionSlots.slotCount {
            let gameView = GameView(
                runner: runnerFactory.makeRunner(),
                overlay: GameOverlayView(),
                infoBar: GameInfoBarView()
            )
            gameViews.append(gameView)
        }

        let viewController = GameScrollViewController(
            gameViews: gameViews,
            closeButton: GameCloseButton(),
            lifecyclePolicy: gameViewSettings.lifecyclePolicy
        )

        viewController.onSettle = { viewModel.didSettle(at: $0) }
        viewController.onRetryDownload = { viewModel.retry(at: $0) }
        viewController.onPlay = { viewModel.enterPlay(at: $0) }
        viewController.onClose = { viewModel.exitPlay() }
        viewController.onToggleLike = { viewModel.toggleLike(at: $0) }
        return viewController
    }

    /// Shows the view model's state on the screen.
    ///
    /// SwiftUI remembers which view model properties are read here, and calls this again
    /// whenever one of them changes. So the screen is always up to date.
    func updateUIViewController(_ viewController: GameScrollViewController, context: Context) {
        viewController.render(GameScrollViewState(
            scrollablePositionCount: viewModel.scrollablePositionCount,
            currentPosition: viewModel.currentPosition,
            isPlaying: viewModel.isPlaying,
            isAppActive: viewModel.isAppActive,
            content: { viewModel.content(at: $0) },
            isLiked: { viewModel.isLiked(at: $0) }
        ))
    }

    static func dismantleUIViewController(_ viewController: GameScrollViewController, coordinator: Coordinator) {
        viewController.tearDown()
    }
}
