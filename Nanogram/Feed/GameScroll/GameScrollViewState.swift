/// Everything the game scroll screen shows. The screen knows nothing about where it comes from.
struct GameScrollViewState {
    /// How many positions the user can scroll through right now. Each one fills the whole screen.
    let scrollablePositionCount: Int
    /// The position the user is on.
    let currentPosition: Int
    let isPlaying: Bool
    /// False while the app is in the background or covered. Then no game runs.
    let isAppActive: Bool
    /// What a position shows, or `nil` if there is no such position.
    let content: (Int) -> FeedPositionContent?
    /// True if the user liked the game at a position.
    let isLiked: (Int) -> Bool

    init(
        scrollablePositionCount: Int = 0,
        currentPosition: Int = 0,
        isPlaying: Bool = false,
        isAppActive: Bool = true,
        content: @escaping (Int) -> FeedPositionContent? = { _ in nil },
        isLiked: @escaping (Int) -> Bool = { _ in false }
    ) {
        self.scrollablePositionCount = scrollablePositionCount
        self.currentPosition = currentPosition
        self.isPlaying = isPlaying
        self.isAppActive = isAppActive
        self.content = content
        self.isLiked = isLiked
    }

    /// A copy of this state with the user on `position`. Everything else stays the same.
    func withCurrentPosition(_ position: Int) -> GameScrollViewState {
        GameScrollViewState(
            scrollablePositionCount: scrollablePositionCount,
            currentPosition: position,
            isPlaying: isPlaying,
            isAppActive: isAppActive,
            content: content,
            isLiked: isLiked
        )
    }
}
