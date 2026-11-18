import UIKit

/// Scrolls through the feed's games, one full-screen position at a time.
///
/// It shows a `GameScrollViewState` and reports what the user did through the `on…` closures.
/// It knows nothing about the view model: `GameScrollView` connects the two.
///
/// Only a few game views exist (see `PositionSlots.slotCount`). They are created once and moved
/// to wherever the user is, so scrolling never creates new views.
final class GameScrollViewController: UIViewController {
    // What the user did, reported to the owner.

    /// Scrolling stopped on this position.
    var onSettle: ((Int) -> Void)?

    /// Retry was tapped for a download problem at this position.
    var onRetryDownload: ((Int) -> Void)?

    /// The game at this position was tapped.
    var onPlay: ((Int) -> Void)?

    /// The like button of the game at this position was tapped.
    var onToggleLike: ((Int) -> Void)?

    /// The Close button was tapped.
    var onClose: (() -> Void)?

    // The parts of the screen. They are created once and live as long as the screen.

    private let scrollView = UIScrollView()
    private let gameViews: [any GameViewProtocol]
    private let closeButton: any GameCloseButtonProtocol
    private let lifecyclePolicy: any GameLifecyclePolicyProtocol

    // What is on the screen right now.

    /// What to show, as last given by `render(_:)`.
    private var state = GameScrollViewState()

    /// Which position each game view shows.
    private var slots = PositionSlots()

    /// Where each position sits. Not ready until the screen size is known.
    private var geometry = GameScrollGeometry()

    /// The position closest to the middle of the screen right now. It changes while the finger
    /// moves, so the game views always surround what the user sees.
    private var nearestPosition = 0

    /// - Parameters:
    ///   - gameViews: one reusable view per slot, so `PositionSlots.slotCount` of them.
    ///   - closeButton: the button that ends play mode.
    ///   - lifecyclePolicy: decides which games run, wait paused, or unload.
    init(
        gameViews: [any GameViewProtocol],
        closeButton: any GameCloseButtonProtocol,
        lifecyclePolicy: any GameLifecyclePolicyProtocol
    ) {
        self.gameViews = gameViews
        self.closeButton = closeButton
        self.lifecyclePolicy = lifecyclePolicy
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Called by the owner

    /// Shows `newState`. Call it again whenever anything in the state changes.
    func render(_ newState: GameScrollViewState) {
        state = newState

        if !geometry.isReady {
            // Nothing is on screen yet, so start on the position the user is on.
            nearestPosition = newState.currentPosition
        }

        showState()
    }

    /// Stops every game and empties the web views. Called when the screen goes away.
    func tearDown() {
        for gameView in gameViews {
            gameView.unload()
        }
    }

    // MARK: - Setup

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setUpScrollView()
        setUpGameViews()
        setUpCloseButton()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let screenSize = scrollView.bounds.size
        guard screenSize != geometry.screenSize else {
            return
        }

        geometry = GameScrollGeometry(screenSize: screenSize)
        showState()

        // The screen size changed, so scroll back to the position the user was on.
        scrollView.contentOffset = geometry.offset(forPosition: nearestPosition)
    }

    private func setUpScrollView() {
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scrollView.isPagingEnabled = true
        scrollView.decelerationRate = .fast
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.scrollsToTop = false
        scrollView.delegate = self
        view.addSubview(scrollView)
    }

    private func setUpGameViews() {
        for gameView in gameViews {
            gameView.isHidden = true
            gameView.onRetryDownload = { [weak self, weak gameView] in
                self?.retryTapped(in: gameView)
            }
            gameView.onPlayRequested = { [weak self, weak gameView] in
                self?.gameTapped(in: gameView)
            }
            gameView.onLikeTapped = { [weak self, weak gameView] in
                self?.likeTapped(in: gameView)
            }
            scrollView.addSubview(gameView)
        }
    }

    private func setUpCloseButton() {
        closeButton.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .primaryActionTriggered)
        view.addSubview(closeButton)
        closeButton.placeInTopRightCorner(of: view.safeAreaLayoutGuide)
    }

    // MARK: - Taps on a game view

    /// Retry was tapped on a game view: report its position to the owner.
    private func retryTapped(in gameView: (any GameViewProtocol)?) {
        guard let position = gameView?.position else {
            return
        }

        onRetryDownload?(position)
    }

    /// A game was tapped. It can be played only while the feed is still.
    private func gameTapped(in gameView: (any GameViewProtocol)?) {
        guard let position = gameView?.position, !isScrolling else {
            return
        }

        onPlay?(position)
    }

    /// The like button was tapped on a game view: report its position to the owner.
    private func likeTapped(in gameView: (any GameViewProtocol)?) {
        guard let position = gameView?.position else {
            return
        }

        onToggleLike?(position)
    }

    // MARK: - Showing the state

    /// Makes the screen match `state`.
    private func showState() {
        guard geometry.isReady else {
            return
        }

        updateContentSize()
        scrollBackIfPastTheEnd()
        updatePlayMode()
        updateGameViews()
    }

    private func updateContentSize() {
        let contentSize = geometry.contentSize(scrollablePositionCount: state.scrollablePositionCount)
        if scrollView.contentSize != contentSize {
            scrollView.contentSize = contentSize
        }
    }

    /// The feed got shorter (the extra last position went away): scroll back to the last one.
    private func scrollBackIfPastTheEnd() {
        let lastPosition = state.scrollablePositionCount - 1
        let isPastTheEnd = state.scrollablePositionCount > 0 && nearestPosition > lastPosition
        if isPastTheEnd, !scrollView.isTracking {
            scrollView.setContentOffset(geometry.offset(forPosition: lastPosition), animated: true)
        }
    }

    /// In play mode the feed stops scrolling and the Close button appears.
    private func updatePlayMode() {
        scrollView.isScrollEnabled = !state.isPlaying
        closeButton.isHidden = !state.isPlaying
    }

    /// Puts the game views around the nearest position and gives each one its content.
    private func updateGameViews() {
        slots = slots.arranged(around: nearestPosition, scrollablePositionCount: state.scrollablePositionCount)

        // Each game view and the position its slot gives it, or `nil` for no position.
        for (gameView, position) in zip(gameViews, slots.positionInEachSlot) {
            if let position, let content = state.content(position) {
                show(content, at: position, in: gameView)
            } else {
                hide(gameView)
            }
        }
    }

    private func show(_ content: FeedPositionContent, at position: Int, in gameView: any GameViewProtocol) {
        gameView.frame = geometry.frame(forPosition: position)
        gameView.isHidden = false
        gameView.configure(position: position, content: content, isLiked: state.isLiked(position))

        let isCurrent = position == state.currentPosition
        gameView.setPlaying(state.isPlaying && isCurrent)

        // Games start loading only when scrolling has stopped, to keep swipes smooth.
        if !isScrolling {
            let lifecycle = lifecyclePolicy.state(
                at: position,
                currentPosition: state.currentPosition,
                isPlaying: state.isPlaying,
                isAppActive: state.isAppActive
            )
            gameView.applyLifecycle(lifecycle)
        }
    }

    private func hide(_ gameView: any GameViewProtocol) {
        gameView.isHidden = true
        gameView.unload()
    }

    // MARK: - Scrolling

    private var isScrolling: Bool {
        scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating
    }

    /// The position closest to where the scroll view is scrolled to right now.
    private var positionAtScrollOffset: Int {
        geometry.nearestPosition(
            toOffsetY: scrollView.contentOffset.y,
            scrollablePositionCount: state.scrollablePositionCount
        )
    }

    /// Called while the finger moves: keeps the game views around what the user sees.
    private func scrollOffsetChanged() {
        guard geometry.isReady else {
            return
        }

        let position = positionAtScrollOffset
        guard position != nearestPosition else {
            return
        }

        nearestPosition = position
        updateGameViews()
    }

    /// Called when scrolling has fully stopped on a position.
    private func scrollingStopped() {
        nearestPosition = positionAtScrollOffset

        // This position is now the current one. The owner confirms it with its next `render`.
        state = state.withCurrentPosition(nearestPosition)
        onSettle?(nearestPosition)

        updateGameViews()
    }
}

extension GameScrollViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollOffsetChanged()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        scrollingStopped()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        scrollingStopped()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollingStopped()
        }
    }
}
