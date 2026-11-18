import UIKit

/// One of the feed's reusable game views. It shows whatever is at one feed position.
///
/// It keeps one web view for its whole life and puts an overlay over it whenever the game is
/// not showing. The view is never blank: it shows the game, its name, a spinner, or an
/// error with a Retry button.
final class GameView: UIView, GameViewProtocol {
    /// Called when Retry is tapped for a download problem, such as a game that could not be
    /// downloaded again. A game that failed to start is retried by the view itself.
    var onRetryDownload: (() -> Void)?
    /// Called when the user taps a game that is ready to play.
    var onPlayRequested: (() -> Void)?
    /// Called when the user taps the like button.
    var onLikeTapped: (() -> Void)?

    /// The feed position this view shows right now.
    private(set) var position: Int?
    private var content: FeedPositionContent?
    private var isLiked = false
    private var isPlaying = false

    private let runner: any GameRunnerProtocol
    private let overlay: any GameOverlayViewProtocol
    private let infoBar: any GameInfoBarViewProtocol
    private lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))

    init(
        runner: any GameRunnerProtocol,
        overlay: any GameOverlayViewProtocol,
        infoBar: any GameInfoBarViewProtocol
    ) {
        self.runner = runner
        self.overlay = overlay
        self.infoBar = infoBar
        super.init(frame: .zero)
        clipsToBounds = true
        backgroundColor = .black

        let fullScreenViews: [UIView] = [runner.webView, overlay]
        for subview in fullScreenViews {
            subview.frame = bounds
            subview.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            addSubview(subview)
        }

        addInfoBarAtTheBottom()

        tapRecognizer.delegate = self
        addGestureRecognizer(tapRecognizer)
        setPlaying(false)

        overlay.onRetry = { [weak self] in self?.retry() }
        infoBar.onLikeTapped = { [weak self] in self?.onLikeTapped?() }
        runner.onStateChange = { [weak self] _ in self?.updateOverlay() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Gives the view its position, content and like state. Calling it again with the same
    /// values does nothing.
    ///
    /// If the content is a different game, the old game is unloaded right away. The new
    /// game starts loading later, when the feed calls `applyLifecycle`.
    func configure(position: Int, content: FeedPositionContent, isLiked: Bool) {
        let isSamePosition = position == self.position
        let isSameContent = content == self.content
        let isSameLike = isLiked == self.isLiked
        guard !(isSamePosition && isSameContent && isSameLike) else {
            return
        }

        self.position = position
        self.content = content
        self.isLiked = isLiked
        accessibilityIdentifier = "feed.position.\(position)"

        let isDifferentGame = game?.id != runner.game?.id
        if isDifferentGame {
            runner.unload()
        }

        updateOverlay()
        updateInfoBar()
    }

    /// Makes the view's game run, wait paused, or unload.
    func applyLifecycle(_ lifecycle: GameLifecycleState) {
        if let game {
            runner.apply(lifecycle, for: game)
        } else {
            runner.unload()
        }
    }

    /// Play mode: the game gets every touch and the info bar hides.
    /// Otherwise a tap on the view asks to play.
    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        runner.webView.isUserInteractionEnabled = playing
        tapRecognizer.isEnabled = !playing
        updateInfoBar()
    }

    /// Empties the view and stops its game.
    func unload() {
        position = nil
        content = nil
        isLiked = false
        setPlaying(false)
        runner.unload()
    }

    /// The game this view shows, if its content is a game.
    private var game: Game? {
        if case .game(let game) = content {
            return game
        }

        return nil
    }

    @objc private func handleTap() {
        if game != nil, runner.state == .ready {
            onPlayRequested?()
        }
    }

    private func retry() {
        if case .failed = runner.state {
            runner.retry()
        } else {
            onRetryDownload?()
        }
    }

    private func updateOverlay() {
        guard let content else {
            return
        }

        let overlayContent = GameOverlayContent(content: content, gameState: runner.state)
        overlay.isHidden = overlayContent == nil

        if let overlayContent {
            overlay.show(overlayContent)
        }
    }

    // MARK: - Info bar

    /// The info bar spans the full width and rests on the bottom edge, above the game.
    private func addInfoBarAtTheBottom() {
        addSubview(infoBar)
        NSLayoutConstraint.activate([
            infoBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            infoBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            infoBar.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    /// The info bar shows only for a game, and only while the user is browsing.
    private func updateInfoBar() {
        guard let game, !isPlaying else {
            infoBar.isHidden = true
            return
        }

        infoBar.isHidden = false
        infoBar.show(GameInfoBarContent(game: game, isLiked: isLiked))
    }
}

extension GameView: UIGestureRecognizerDelegate {
    /// Taps on the info bar, such as on the like button, don't start the game.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchedView = touch.view else {
            return true
        }

        return !touchedView.isDescendant(of: infoBar)
    }
}
