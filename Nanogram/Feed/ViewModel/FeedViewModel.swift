import Foundation
import Observation
import os

/// Owns the feed: loading pages, deciding which games stay in memory, loading forgotten games
/// again, looping, play mode, likes and app activity. The UI shows this state and reports
/// what the user did.
///
/// It makes the decisions; two helpers do the mechanics:
/// - `GamesInMemory` stores the kept games and what is known about the others.
/// - Two `PageDownloaderProtocol`s download pages, one for new pages and one for forgotten ones.
///
/// Words used here:
/// - A **page** is always an API page: one server response with a batch of games.
/// - A **position** is one full-screen spot in the feed, counted from 0 at the top.
/// - A **game index** is the place of a game among the loaded games, counted from 0.
///
/// While the server has more pages, a position and its game index are the same number.
/// Once it has no more, the feed loops: the position after the last game shows the first game
/// again, and so on forever. Positions keep counting up; `gameIndex(at:)` maps a position to
/// the game it shows.
@Observable
@MainActor
final class FeedViewModel: FeedViewModelProtocol {
    private(set) var state: State = .loadingFirstPage
    private(set) var currentPosition = 0
    private(set) var isPlaying = false
    /// False while the app is in the background or covered. Then no game runs.
    private(set) var isAppActive = true

    /// The kept games, and what is known about kept games that aren't loaded.
    private var gamesInMemory = GamesInMemory()
    /// The API pages loaded so far, and which game indices each one covers.
    private var loadedPages = LoadedPages()
    /// The API numbers pages starting at 1. `nil` means the feed has ended.
    private var nextPage: Int? = 1
    /// Ids of the games the user liked. Saved on the device by `likedGamesStore`.
    private var likedGameIDs: Set<String>

    /// Downloads the first and the next pages.
    @ObservationIgnored private let nextPageDownloader: any PageDownloaderProtocol
    /// Downloads forgotten pages again. Separate from `nextPageDownloader`, so going back
    /// never blocks loading new pages.
    @ObservationIgnored private let removedPageDownloader: any PageDownloaderProtocol
    @ObservationIgnored private let likedGamesStore: any LikedGamesStoreProtocol
    @ObservationIgnored private let configuration: Configuration

    init(
        nextPageDownloader: any PageDownloaderProtocol,
        removedPageDownloader: any PageDownloaderProtocol,
        likedGamesStore: any LikedGamesStoreProtocol,
        configuration: Configuration = Configuration()
    ) {
        self.nextPageDownloader = nextPageDownloader
        self.removedPageDownloader = removedPageDownloader
        self.likedGamesStore = likedGamesStore
        self.configuration = configuration
        likedGameIDs = likedGamesStore.loadLikedGameIDs()
    }

    // MARK: - What the feed shows

    /// Number of games loaded so far, including ones removed from memory.
    var loadedGameCount: Int { loadedPages.gameCount }

    /// How many positions the user can scroll through right now. The scroll view lays out
    /// exactly this many.
    ///
    /// While more pages are coming: one position per game, plus one extra last position while
    /// it shows loading or an error. Once the feed loops: always one position after the current
    /// one, so there is always somewhere to swipe to.
    var scrollablePositionCount: Int {
        if isLooping {
            // Positions 0 up to and including the one after the current position.
            let countUpToTheNextPosition = currentPosition + 2
            return max(loadedGameCount, countUpToTheNextPosition)
        }

        if loadMoreContent == nil {
            return loadedGameCount
        }

        return loadedGameCount + 1
    }

    func game(at position: Int) -> Game? {
        gamesInMemory.game(at: gameIndex(at: position))
    }

    /// True if the user liked the game at `position`.
    func isLiked(at position: Int) -> Bool {
        guard let game = game(at: position) else {
            return false
        }

        return likedGameIDs.contains(game.id)
    }

    /// What the given position shows, or `nil` if it is outside the feed.
    func content(at position: Int) -> FeedPositionContent? {
        guard position >= 0, position < scrollablePositionCount else {
            return nil
        }

        if isLoadMorePosition(position) {
            return loadMoreContent
        }

        let index = gameIndex(at: position)
        if let game = gamesInMemory.game(at: index) {
            return .game(game)
        }

        if gamesInMemory.isMissing(index) {
            return .gameMissing
        }

        if let error = gamesInMemory.reloadError(at: index) {
            return .reloadFailed(error)
        }

        return .reloadingGame
    }

    /// True once the server has no more pages: the feed then starts over from the first game.
    private var isLooping: Bool { nextPage == nil && loadedGameCount > 0 }

    /// True for the load-more position: the extra last position that shows the next page
    /// loading, or why it failed. A looping feed has none.
    private func isLoadMorePosition(_ position: Int) -> Bool {
        !isLooping && position == loadedGameCount
    }

    /// The game index that `position` shows. Past the last game of a looping feed, positions
    /// start over from the first game.
    private func gameIndex(at position: Int) -> Int {
        guard isLooping, position >= 0 else {
            return position
        }

        return position % loadedGameCount
    }

    /// `position` moved inside the feed: not before the first position, not after the last one.
    private func clampedToFeed(_ position: Int) -> Int {
        let lastPosition = max(scrollablePositionCount - 1, 0)
        if position < 0 {
            return 0
        }

        if position > lastPosition {
            return lastPosition
        }

        return position
    }

    /// What the load-more position shows: a spinner while the next page loads, or the error if
    /// it failed. `nil` when no next page is being loaded, so there is no load-more position.
    private var loadMoreContent: FeedPositionContent? {
        switch state {
        case .loaded(.loading): .loadingMore
        case .loaded(.failed(let error)): .loadMoreFailed(error)
        case .loaded(.idle), .loadingFirstPage, .failedInitial: nil
        }
    }

    // MARK: - What the user did

    /// Loads the first page. Safe to call more than once.
    func start() {
        if state == .loadingFirstPage {
            loadNextPage()
        }
    }

    /// Tries the failed first or next page again. Never moves the user.
    func retry() {
        switch state {
        case .failedInitial, .loaded(.failed): loadNextPage()
        case .loadingFirstPage, .loaded(.idle), .loaded(.loading): break
        }
    }

    /// Retry from the error shown at `position`.
    func retry(at position: Int) {
        if isLoadMorePosition(position) {
            retry()
            return
        }

        guard let pageGameIndices = loadedPages.gameIndicesOfPage(containing: gameIndex(at: position)) else {
            return
        }

        gamesInMemory = gamesInMemory.clearingReloadProblems(gameIndices: pageGameIndices)
        reloadRemovedGames()
    }

    /// Called once scrolling stops on a position.
    func didSettle(at position: Int) {
        currentPosition = clampedToFeed(position)
        forgetGamesNoLongerKept()
        loadNextPageIfNearTheEnd()
        reloadRemovedGames()
    }

    /// Only the game the user is on can be played.
    func enterPlay(at position: Int) {
        guard position == currentPosition, game(at: position) != nil else {
            return
        }

        isPlaying = true
    }

    func exitPlay() {
        isPlaying = false
    }

    /// The app is on screen and in use again: the current game runs again.
    func appBecameActive() {
        isAppActive = true
    }

    /// The app went to the background or got covered, for example by Control Center:
    /// the current game is paused.
    func appBecameInactive() {
        isAppActive = false
    }

    /// Likes the game at `position`, or removes the like if it's already liked.
    /// The change is saved on the device right away.
    func toggleLike(at position: Int) {
        guard let game = game(at: position) else {
            return
        }

        if likedGameIDs.contains(game.id) {
            likedGameIDs.remove(game.id)
        } else {
            likedGameIDs.insert(game.id)
        }

        likedGamesStore.saveLikedGameIDs(likedGameIDs)
    }

    // MARK: - Loading new pages

    private func loadNextPageIfNearTheEnd() {
        let gamesLeftAhead = loadedGameCount - 1 - currentPosition
        if state == .loaded(loadMore: .idle), gamesLeftAhead <= configuration.prefetchDistance {
            loadNextPage()
        }
    }

    /// Loads the first page, or the next one once the feed is showing.
    private func loadNextPage() {
        guard nextPageDownloader.downloadingPage == nil, let page = nextPage else {
            return
        }

        let isFirstPage = !isShowingFeed
        state = isFirstPage ? .loadingFirstPage : .loaded(loadMore: .loading)
        Log.feed.info("Loading page \(page)")

        nextPageDownloader.download(page) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .success(let feedPage):
                nextPageLoaded(feedPage, page: page)
            case .failure(let error):
                nextPageFailed(page, error: error, isFirstPage: isFirstPage)
            }
        }
    }

    private func nextPageLoaded(_ feedPage: FeedPage, page: Int) {
        loadedPages = loadedPages.appending(page: page, gameCount: feedPage.games.count)
        nextPage = feedPage.nextPage
        state = .loaded(loadMore: .idle)

        if let pageGameIndices = loadedPages.gameIndices(of: page) {
            gamesInMemory = gamesInMemory.storing(
                feedPage.games,
                gameIndices: pageGameIndices,
                keeping: gameIndicesToKeep
            )
        }

        // An empty last page removes the load-more position the user may be sitting on.
        currentPosition = clampedToFeed(currentPosition)

        // A short page can leave the user near the end already.
        loadNextPageIfNearTheEnd()

        // If that was the last page, the next positions loop back to games removed long ago.
        reloadRemovedGames()
    }

    private func nextPageFailed(_ page: Int, error: FeedError, isFirstPage: Bool) {
        Log.feed.error("Page \(page) failed: \(String(describing: error), privacy: .public)")

        if isFirstPage {
            state = .failedInitial(error)
        } else {
            state = .loaded(loadMore: .failed(error))
        }
    }

    /// True once the first page has loaded and the feed is on screen.
    private var isShowingFeed: Bool {
        if case .loaded = state {
            return true
        }

        return false
    }

    // MARK: - Keeping memory bounded

    /// The game indices that stay in memory: the games shown near the current position.
    /// With the default configuration that is 21 to 30 games (see `Configuration.minimumGamesKeptAhead`).
    private var gameIndicesToKeep: Set<Int> {
        let firstPosition = currentPosition - configuration.gamesKeptBehind
        let lastPosition = lastPositionToKeep()
        return Set((firstPosition...lastPosition).map(gameIndex(at:)))
    }

    /// `minimumGamesKeptAhead` positions after the current one, moved forward to the last game of
    /// its API page. So a page that was just loaded is never removed and loaded again.
    private func lastPositionToKeep() -> Int {
        let position = currentPosition + configuration.minimumGamesKeptAhead
        let index = gameIndex(at: position)
        guard let pageGameIndices = loadedPages.gameIndicesOfPage(containing: index) else {
            return position
        }

        let gamesLeftInPage = pageGameIndices.upperBound - 1 - index
        return position + gamesLeftInPage
    }

    /// Called after the user moved: forgets everything about games that are no longer kept,
    /// and stops downloading a page the user has moved away from.
    private func forgetGamesNoLongerKept() {
        let gameIndicesToKeep = gameIndicesToKeep
        gamesInMemory = gamesInMemory.keepingOnly(gameIndicesToKeep)

        guard let downloadingPage = removedPageDownloader.downloadingPage else {
            return
        }

        if !loadedPages.pageHasGame(downloadingPage, in: gameIndicesToKeep) {
            removedPageDownloader.cancel()
        }
    }

    // MARK: - Loading forgotten games again

    /// Downloads the page of the closest forgotten game again, one page at a time.
    private func reloadRemovedGames() {
        guard removedPageDownloader.downloadingPage == nil, isShowingFeed else {
            return
        }

        guard let position = closestRemovedGamePosition() else {
            return
        }

        guard let page = loadedPages.page(containing: gameIndex(at: position)),
              let pageGameIndices = loadedPages.gameIndices(of: page) else {
            return
        }

        Log.feed.info("Reloading removed page \(page)")

        removedPageDownloader.download(page) { [weak self] result in
            guard let self else {
                return
            }

            switch result {
            case .success(let feedPage):
                gamesInMemory = gamesInMemory.storingReloadedPage(
                    feedPage.games,
                    gameIndices: pageGameIndices,
                    keeping: gameIndicesToKeep
                )
                reloadRemovedGames()
            case .failure(let error):
                Log.feed.error("Reload of page \(page) failed: \(String(describing: error), privacy: .public)")
                gamesInMemory = gamesInMemory.recordingReloadError(
                    error,
                    gameIndices: pageGameIndices,
                    keeping: gameIndicesToKeep
                )
            }
        }
    }

    /// The position nearest to the user whose game was removed from memory and must be
    /// loaded again, or `nil` if there is none nearby.
    private func closestRemovedGamePosition() -> Int? {
        for position in nearbyPositionsClosestFirst() {
            if isRemovedGame(at: position) {
                return position
            }
        }

        return nil
    }

    /// The positions around the user, sorted by how close they are to the current one.
    /// With the user on 10 and a search distance of 3: `[10, 9, 11, 8, 12, 7, 13]`.
    private func nearbyPositionsClosestFirst() -> [Int] {
        var positions = [currentPosition]
        for distance in 1...reloadSearchDistance {
            positions.append(currentPosition - distance)
            positions.append(currentPosition + distance)
        }

        return positions
    }

    /// How far from the current position to look for removed games: the prefetch distance,
    /// but at least 1, so the games right next to the user are always checked.
    private var reloadSearchDistance: Int {
        max(configuration.prefetchDistance, 1)
    }

    /// True if the game at `position` was removed from memory and is waiting to be loaded
    /// again. That is exactly when the position shows the "reloading" spinner.
    private func isRemovedGame(at position: Int) -> Bool {
        content(at: position) == .reloadingGame
    }
}
