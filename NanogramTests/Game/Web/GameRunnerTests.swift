import Testing
import WebKit
@testable import Nanogram

/// Drives a real `WKWebView`, so these use generous timeouts for the first WebContent launch.
@MainActor
@Suite(.serialized)
struct GameRunnerTests {
    private let factory = GameRunnerFactory(settings: GameViewSettings())

    /// These tests are about the concrete `GameRunner`, including the parts its protocol
    /// leaves out, so they take the runner as its real type.
    private func makeRunner() -> GameRunner {
        guard let runner = factory.makeRunner() as? GameRunner else {
            fatalError("GameRunnerFactory should make GameRunner instances")
        }

        return runner
    }

    private func makeGame(id: String = "g1", html: String? = "<html><body>Game</body></html>") -> Game {
        Game(id: id, title: "Game", html: html, creatorUsername: "c", plays: 0, likes: 0)
    }

    @Test func loadingAGameBecomesReady() async {
        let runner = makeRunner()
        runner.apply(.running, for: makeGame())
        #expect(runner.state == .loading)

        await waitUntil(timeout: .seconds(15)) { runner.state == .ready }
        #expect(runner.game?.id == "g1")
    }

    @Test func gamesStartHiddenAndOnlyTheRunningOneIsRevealed() async throws {
        let runner = makeRunner()
        runner.apply(.preloadedSuspended, for: makeGame())
        await waitUntil(timeout: .seconds(15)) { runner.state == .ready }
        #expect(try await visibilityState(of: runner) == "hidden")

        runner.setSuspended(false)
        #expect(try await visibilityState(of: runner) == "visible")

        runner.setSuspended(true)
        #expect(try await visibilityState(of: runner) == "hidden")
    }

    /// Script calls are handled in order, so this observes the effect of earlier suspend/resume calls.
    private func visibilityState(of runner: GameRunner) async throws -> String? {
        try await runner.webView.evaluateJavaScript("document.visibilityState") as? String
    }

    @Test func pausedGameIsSilentEvenWithWebAudio() async throws {
        // A game that plays a continuous tone with the Web Audio API, the way most web games
        // make sound. "running" means the tone is playing.
        let html = """
            <html><body><script>
            window.gameAudio = new AudioContext();
            const tone = window.gameAudio.createOscillator();
            tone.connect(window.gameAudio.destination);
            tone.start();
            </script></body></html>
            """
        let game = makeGame(html: html)
        let runner = makeRunner()

        // WebKit plays sound only for a web view that is on screen, like the running game in
        // the app. So the web view goes into the app's window for this test.
        let window = try #require(Self.appWindow(), "The test host app should have a window")
        window.addSubview(runner.webView)
        defer { runner.webView.removeFromSuperview() }

        runner.apply(.running, for: game)
        await waitUntil(timeout: .seconds(15)) { runner.state == .ready }

        let stateWhileRunning = try await waitForAudioState(of: runner) { $0 == "running" }
        #expect(stateWhileRunning == "running", "Web Audio state while running: \(String(describing: stateWhileRunning))")

        // The same call the feed makes for an off-screen game, or when the app goes to the background.
        runner.apply(.preloadedSuspended, for: game)
        let stateWhilePaused = try await waitForAudioState(of: runner) { $0 != "running" }
        #expect(stateWhilePaused != "running")

        runner.apply(.running, for: game)
        let stateAfterResuming = try await waitForAudioState(of: runner) { $0 == "running" }
        #expect(stateAfterResuming == "running")
    }

    /// The window of the app that hosts the tests.
    private static func appWindow() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else {
                continue
            }

            for window in windowScene.windows where window.isKeyWindow {
                return window
            }
        }

        return nil
    }

    /// The state of the game's Web Audio context, such as "running", "suspended" or "interrupted".
    private func audioState(of runner: GameRunner) async throws -> String? {
        try await runner.webView.evaluateJavaScript("window.gameAudio.state") as? String
    }

    /// Asks for the audio state until it is what the test expects, because WebKit changes it
    /// a moment after being told to. Gives up after a few seconds and returns the last state.
    private func waitForAudioState(
        of runner: GameRunner,
        until isExpected: (String?) -> Bool
    ) async throws -> String? {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(5)

        var state = try await audioState(of: runner)
        while !isExpected(state), clock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
            state = try await audioState(of: runner)
        }

        return state
    }

    @Test(arguments: ["", nil] as [String?])
    func gameWithoutHTMLFailsRightAway(html: String?) {
        let runner = makeRunner()
        runner.apply(.running, for: makeGame(html: html))
        #expect(runner.state == .failed(.unavailable))
    }

    @Test func gameThatIsNotReadyInTimeFails() async {
        let runner = GameRunner(configuration: WKWebViewConfiguration(), loadTimeout: .zero)
        runner.apply(.running, for: makeGame())
        await waitUntil(timeout: .seconds(5)) { runner.state == .failed(.timedOut) }

        // A late finish doesn't override the timeout; Retry does.
        try? await Task.sleep(for: .milliseconds(300))
        #expect(runner.state == .failed(.timedOut))
    }

    @Test func aCrashedGameFailsAndRetryLoadsItAgain() async {
        let runner = makeRunner()
        runner.apply(.running, for: makeGame())
        await waitUntil(timeout: .seconds(15)) { runner.state == .ready }

        runner.webViewWebContentProcessDidTerminate(runner.webView)
        #expect(runner.state == .failed(.processTerminated))

        runner.retry()
        #expect(runner.state == .loading)
        await waitUntil(timeout: .seconds(15)) { runner.state == .ready }
    }

    @Test func aCrashWhileNothingIsLoadedIsIgnored() {
        let runner = makeRunner()
        runner.webViewWebContentProcessDidTerminate(runner.webView)
        #expect(runner.state == .idle)
    }

    @Test func unloadingResetsEverything() async {
        let runner = makeRunner()
        runner.apply(.running, for: makeGame())
        await waitUntil(timeout: .seconds(15)) { runner.state == .ready }

        runner.apply(.unloaded, for: makeGame())

        #expect(runner.state == .idle)
        #expect(runner.game == nil)
    }

    @Test func rebindingToAnotherGameStartsFresh() async throws {
        let runner = makeRunner()
        runner.apply(.running, for: makeGame(id: "a", html: "<html><script>window.leak = 42</script></html>"))
        await waitUntil(timeout: .seconds(15)) { runner.state == .ready }

        runner.apply(.running, for: makeGame(id: "b"))
        #expect(runner.state == .loading)
        await waitUntil(timeout: .seconds(15)) { runner.state == .ready }

        #expect(runner.game?.id == "b")
        let leaked = try await runner.webView.evaluateJavaScript("typeof window.leak")
        #expect(leaked as? String == "undefined")
    }

    @Test func applyingTheSameGameAgainDoesNotReload() async {
        let runner = makeRunner()
        let game = makeGame()
        runner.apply(.preloadedSuspended, for: game)
        await waitUntil(timeout: .seconds(15)) { runner.state == .ready }

        runner.apply(.running, for: game)

        #expect(runner.state == .ready)
    }
}
