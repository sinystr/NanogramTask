import WebKit

/// Lets the app tell a game that it is hidden or visible.
///
/// A web view that is off screen still counts as visible to the web page, so its game would
/// keep running. Most web games pause when the page says it is hidden. This script lets
/// the app decide what the page says, and announces every change to the game.
///
/// Every page starts hidden, so a game that is loaded early never runs. The app makes the
/// page visible when its game should run.
@MainActor
enum GameVisibilityScript {
    /// Added to every game page before the game's own code runs.
    static let userScript = WKUserScript(
        source: source,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )

    /// JavaScript that tells the current game it is now hidden or visible.
    static func javaScriptToSetHidden(_ hidden: Bool) -> String {
        "window.__nanogramSetHidden && window.__nanogramSetHidden(\(hidden));"
    }

    private static let source = """
        (() => {
          let hidden = true;
          const define = (name, getter) =>
            Object.defineProperty(Document.prototype, name, { configurable: true, get: getter });
          define('hidden', () => hidden);
          define('visibilityState', () => (hidden ? 'hidden' : 'visible'));
          window.__nanogramSetHidden = (value) => {
            if (hidden === value) return;
            hidden = value;
            document.dispatchEvent(new Event('visibilitychange'));
          };
        })();
        """
}
