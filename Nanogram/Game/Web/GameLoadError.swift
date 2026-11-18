import Foundation

/// Why a game can't be shown, with text the game view can show to the user.
enum GameLoadError: Error, Equatable {
    /// The game has no content to load.
    case unavailable
    case loadFailed
    case timedOut
    /// The game's web process crashed or was stopped by the system, usually to free memory.
    case processTerminated

    var title: String {
        switch self {
        case .unavailable: String(localized: "Couldn't load this game")
        case .loadFailed: String(localized: "This game couldn't load")
        case .timedOut: String(localized: "This game is taking too long")
        case .processTerminated: String(localized: "This game stopped unexpectedly")
        }
    }

    var message: String {
        switch self {
        case .unavailable: String(localized: "It can't be shown right now. Swipe to keep playing other games.")
        case .loadFailed: String(localized: "Something went wrong while loading it. Please try again.")
        case .timedOut: String(localized: "It didn't finish loading in time. Please try again.")
        case .processTerminated: String(localized: "It may have used too much memory. Please try again.")
        }
    }
}
