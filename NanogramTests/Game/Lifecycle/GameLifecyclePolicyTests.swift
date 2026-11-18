import Testing
@testable import Nanogram

struct GameLifecyclePolicyTests {
    /// What `policy` says about `position`, with the user browsing in an active app unless
    /// a test says otherwise.
    private func lifecycle(
        at position: Int,
        currentPosition: Int = 5,
        isPlaying: Bool = false,
        isAppActive: Bool = true,
        policy: GameLifecyclePolicy = GameLifecyclePolicy()
    ) -> GameLifecycleState {
        policy.state(at: position, currentPosition: currentPosition, isPlaying: isPlaying, isAppActive: isAppActive)
    }

    // MARK: - Browsing

    @Test func currentPositionRuns() {
        #expect(lifecycle(at: 5) == .running)
    }

    @Test func nextPositionIsPreloadedButSuspended() {
        #expect(lifecycle(at: 6) == .preloadedSuspended)
    }

    @Test func previousPositionIsPreloadedButSuspended() {
        #expect(lifecycle(at: 4) == .preloadedSuspended)
    }

    @Test(arguments: [0, 3, 7, 8, 100])
    func farPositionsAreUnloaded(position: Int) {
        #expect(lifecycle(at: position) == .unloaded)
    }

    @Test func firstPositionWithNothingBefore() {
        #expect(lifecycle(at: 0, currentPosition: 0) == .running)
        #expect(lifecycle(at: 1, currentPosition: 0) == .preloadedSuspended)
    }

    @Test func adjacentPositionsAreUnloadedWhenPreloadingIsOff() {
        let policy = GameLifecyclePolicy(preloadsAdjacentGames: false)
        #expect(lifecycle(at: 5, policy: policy) == .running)
        #expect(lifecycle(at: 4, policy: policy) == .unloaded)
        #expect(lifecycle(at: 6, policy: policy) == .unloaded)
    }

    // MARK: - Play mode

    @Test func playModeKeepsOnlyThePlayedGame() {
        #expect(lifecycle(at: 5, isPlaying: true) == .running)
        #expect(lifecycle(at: 6, isPlaying: true) == .unloaded)
        #expect(lifecycle(at: 4, isPlaying: true) == .unloaded)
    }

    // MARK: - App in the background

    @Test func currentGameIsPausedWhileTheAppIsNotActive() {
        #expect(lifecycle(at: 5, isAppActive: false) == .preloadedSuspended)
    }

    @Test func playedGameIsPausedNotUnloadedWhileTheAppIsNotActive() {
        // Paused, not unloaded: coming back continues the game where the player left it.
        #expect(lifecycle(at: 5, isPlaying: true, isAppActive: false) == .preloadedSuspended)
    }

    @Test func otherGamesStayAsTheyWereWhileTheAppIsNotActive() {
        #expect(lifecycle(at: 4, isAppActive: false) == .preloadedSuspended)
        #expect(lifecycle(at: 6, isAppActive: false) == .preloadedSuspended)
        #expect(lifecycle(at: 8, isAppActive: false) == .unloaded)
    }

    @Test(arguments: [3, 4, 5, 6, 7])
    func noGameRunsWhileTheAppIsNotActive(position: Int) {
        #expect(lifecycle(at: position, isAppActive: false) != .running)
    }
}
