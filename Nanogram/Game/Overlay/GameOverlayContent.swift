import Foundation

/// What the overlay shows on a game view while its game is not showing: the game's name, a spinner, or an
/// error with a Retry button.
///
/// It knows nothing about views, so the rules can be unit-tested.
struct GameOverlayContent: Equatable {
    let title: String?
    let detail: String?
    let showsSpinner: Bool
    let showsRetry: Bool
    let background: Background

    init(
        title: String? = nil,
        detail: String? = nil,
        showsSpinner: Bool = false,
        showsRetry: Bool = false,
        background: Background = .blueGradient
    ) {
        self.title = title
        self.detail = detail
        self.showsSpinner = showsSpinner
        self.showsRetry = showsRetry
        self.background = background
    }
}

extension GameOverlayContent {
    /// The overlay for a game view, or `nil` when the game itself should be visible.
    /// A game view is never blank: it shows either an overlay or a game that is ready.
    init?(content: FeedPositionContent, gameState: GameLoadState) {
        switch (content, gameState) {
        case (.game, .ready):
            return nil
        case (.game(let game), .idle):
            self.init(title: game.displayTitle, detail: Self.byline(for: game), background: .driftingGlows)
        case (.game(let game), .loading):
            self.init(title: game.displayTitle, showsSpinner: true, background: .driftingGlows)
        case (.game, .failed(let error)):
            self.init(title: error.title, detail: error.message, showsRetry: true)
        case (.reloadingGame, _):
            self.init(showsSpinner: true, background: .driftingGlows)
        case (.loadingMore, _):
            self.init(title: String(localized: "Loading more games…"), showsSpinner: true, background: .driftingGlows)
        case (.loadMoreFailed(let error), _):
            self.init(title: error.title, detail: error.message, showsRetry: true, background: .driftingGlows)
        case (.reloadFailed(let error), _):
            self.init(title: error.title, detail: error.message, showsRetry: true)
        case (.gameMissing, _):
            let error = GameLoadError.unavailable
            self.init(title: error.title, detail: error.message, showsRetry: true)
        }
    }

    /// "by <creator>", or `nil` when the server didn't say who made the game.
    private static func byline(for game: Game) -> String? {
        guard let username = game.creatorUsername else {
            return nil
        }

        return String(localized: "by \(username)")
    }
}
