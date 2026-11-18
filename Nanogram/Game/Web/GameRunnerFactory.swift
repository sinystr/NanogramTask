import WebKit

/// Creates the game runners, all sharing one web view setup.
///
/// Games are kept apart from each other: they can't read each other's cookies or saved
/// data, and nothing a game saves is kept after the app closes.
@MainActor
final class GameRunnerFactory {
    private let configuration: WKWebViewConfiguration
    private let settings: GameViewSettings

    init(settings: GameViewSettings) {
        self.settings = settings
        configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        // Games may play sound and video without waiting for a tap.
        configuration.mediaTypesRequiringUserActionForPlayback = []
        // Nothing a game saves is written to disk.
        configuration.websiteDataStore = .nonPersistent()
        // Every game page starts hidden, and the runner tells it when it is visible.
        configuration.userContentController.addUserScript(GameVisibilityScript.userScript)
    }

    /// The factory knows the concrete `GameRunner`, because creating runners is its job.
    /// Everyone else gets them as `GameRunnerProtocol`.
    func makeRunner() -> any GameRunnerProtocol {
        GameRunner(configuration: configuration, loadTimeout: settings.loadTimeout)
    }
}
