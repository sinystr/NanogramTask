import Foundation

extension Game {
    /// The game's title, or "Untitled game" when the server didn't send one.
    var displayTitle: String {
        guard let title else {
            return String(localized: "Untitled game")
        }

        return title
    }
}
