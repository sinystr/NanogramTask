import WebKit
import os

/// Runs games in one web view that lives as long as the feed.
///
/// It loads a game, clears everything between games, pauses and resumes the game, and
/// keeps track of whether the game is loading, ready or failed.
@MainActor
final class GameRunner: NSObject, GameRunnerProtocol {
    let webView: WKWebView
    /// Called every time `state` changes.
    var onStateChange: ((GameLoadState) -> Void)?

    private(set) var state: GameLoadState = .idle {
        didSet {
            if state != oldValue {
                stateChanged()
            }
        }
    }
    /// The game this web view holds right now.
    private(set) var game: Game?

    private let loadTimeout: Duration
    /// The load of the current game. News about any other load is ignored.
    private var currentGameLoad: WKNavigation?
    private var timeoutTask: Task<Void, Never>?
    /// Starts as true because every new web page starts hidden (see `GameVisibilityScript`).
    private var isSuspended = true
    /// Measures how long the current load takes, for Instruments.
    private var loadMeasurement: OSSignpostIntervalState?

    init(configuration: WKWebViewConfiguration, loadTimeout: Duration) {
        self.loadTimeout = loadTimeout
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        // The game must get every touch, so the web view itself never scrolls or bounces.
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
    }

    // MARK: - Called by the game view

    /// Makes `game` run, wait paused, or unload.
    ///
    /// A game that is already loading, ready or failed is not loaded again. A failed game
    /// is loaded again only when the user taps Retry.
    func apply(_ lifecycle: GameLifecycleState, for game: Game) {
        guard lifecycle != .unloaded else {
            unload()
            return
        }
        setSuspended(lifecycle == .preloadedSuspended)
        let isSameGame = game.id == self.game?.id
        let isAlreadyHere = isSameGame && state != .idle
        if !isAlreadyHere {
            self.game = game
            loadFromScratch()
        }
    }

    /// Tries to load a failed game again.
    func retry() {
        if case .failed = state {
            loadFromScratch()
        }
    }

    /// Stops the game and frees its memory.
    func unload() {
        let isAlreadyEmpty = game == nil && state == .idle
        if !isAlreadyEmpty {
            game = nil
            clearWebView()
        }
    }

    /// Pauses (`true`) or resumes (`false`) the game.
    func setSuspended(_ suspended: Bool) {
        guard suspended != isSuspended else {
            return
        }

        isSuspended = suspended
        let action = suspended ? "Pausing" : "Resuming"
        Log.lifecycle.debug("\(action, privacy: .public) game \(self.gameIDForLogs, privacy: .public)")
        tellGameWhetherItIsSuspended()
    }

    // MARK: - Loading

    private func loadFromScratch() {
        clearWebView()
        guard let game else {
            return
        }

        // A game without a web page can't run. It shows an error, and the user swipes on.
        guard let html = game.html, !html.isEmpty else {
            state = .failed(.unavailable)
            return
        }

        Log.game.info("Loading game \(game.id, privacy: .public)")
        loadMeasurement = Log.gameSignposter.beginInterval("GameLoad", id: Log.gameSignposter.makeSignpostID())
        state = .loading
        // No base URL: each game is treated as its own separate website.
        currentGameLoad = webView.loadHTMLString(html, baseURL: nil)
    }

    /// Removes everything the last game left behind by loading an empty web page.
    private func clearWebView() {
        webView.stopLoading()
        currentGameLoad = nil
        if let emptyPage = URL(string: "about:blank") {
            webView.load(URLRequest(url: emptyPage))
        }
        state = .idle
    }

    /// Ends loading as ready or failed. Once loading has ended, late news about it is ignored.
    private func finishLoading(_ result: GameLoadState) {
        if state == .loading {
            state = result
        }
    }

    private func stateChanged() {
        restartTimeout()
        endLoadMeasurementIfLoadingEnded()
        stopLoadingIfFailed()
        onStateChange?(state)
    }

    /// The timeout runs only while the game is loading.
    private func restartTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard state == .loading else {
            return
        }

        timeoutTask = Task { [weak self, loadTimeout] in
            try? await Task.sleep(for: loadTimeout)
            guard !Task.isCancelled else {
                return
            }

            self?.finishLoading(.failed(.timedOut))
        }
    }

    private func endLoadMeasurementIfLoadingEnded() {
        guard state != .loading, let loadMeasurement else {
            return
        }

        let result = String(describing: state)
        Log.gameSignposter.endInterval("GameLoad", loadMeasurement, "\(result, privacy: .public)")
        self.loadMeasurement = nil
    }

    private func stopLoadingIfFailed() {
        guard case .failed(let error) = state else {
            return
        }

        let reason = String(describing: error)
        Log.game.error("Game \(self.gameIDForLogs, privacy: .public) failed: \(reason, privacy: .public)")
        webView.stopLoading()
    }

    /// The current game's id, or "-" when there is none.
    private var gameIDForLogs: String {
        guard let game else {
            return "-"
        }

        return game.id
    }

    /// Silences or un-silences all of the game's sound and video, including Web Audio, and
    /// tells the game whether it is hidden so it can pause its own loop.
    ///
    /// Only `setAllMediaPlaybackSuspended` is used: WebKit lifts it again when the game resumes.
    /// `pauseAllMediaPlayback` would act like pressing pause, and the sound would stay off.
    private func tellGameWhetherItIsSuspended() {
        webView.setAllMediaPlaybackSuspended(isSuspended)
        webView.evaluateJavaScript(GameVisibilityScript.javaScriptToSetHidden(isSuspended))
    }
}

extension GameRunner: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        // The new web page starts hidden. Make it visible now if this game should be running.
        if isCurrentGameLoad(navigation) {
            tellGameWhetherItIsSuspended()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isCurrentGameLoad(navigation) {
            finishLoading(.ready)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        loadFailed(navigation, error: error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        loadFailed(navigation, error: error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        // A crash matters while loading and also after the game is ready.
        currentGameLoad = nil
        if state == .loading || state == .ready {
            state = .failed(.processTerminated)
        }
    }

    /// Games stay on their own web page: a tapped link that would replace the whole game is blocked.
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        // A link without a target frame opens a new window, which would also replace the game.
        let replacesWholePage: Bool
        if let targetFrame = navigationAction.targetFrame {
            replacesWholePage = targetFrame.isMainFrame
        } else {
            replacesWholePage = true
        }
        let wasStartedByUser = navigationAction.navigationType != .other
        let shouldBlock = replacesWholePage && wasStartedByUser
        decisionHandler(shouldBlock ? .cancel : .allow)
    }

    private func loadFailed(_ navigation: WKNavigation?, error: any Error) {
        // We cancel loads ourselves when we stop or replace a game. That is not a failure.
        let wasCancelled = (error as NSError).code == NSURLErrorCancelled
        if isCurrentGameLoad(navigation), !wasCancelled {
            finishLoading(.failed(.loadFailed))
        }
    }

    private func isCurrentGameLoad(_ navigation: WKNavigation?) -> Bool {
        navigation != nil && navigation === currentGameLoad
    }
}
