import Foundation

/// What the info bar at the bottom of a game view shows.
///
/// It knows nothing about views, so the rules can be unit-tested.
struct GameInfoBarContent: Equatable {
    let title: String

    /// "@username", or `nil` when the server didn't say who made the game.
    let creator: String?

    /// "285K plays", or `nil` when the server didn't send the number.
    let plays: String?

    /// The like count shown under the heart, counting the user's own like.
    /// `nil` when the server didn't send the number.
    let likes: String?

    let isLiked: Bool

    /// `locale` decides how numbers are written ("7.9K" or "7,9K"). The app uses the user's own.
    init(game: Game, isLiked: Bool, locale: Locale = .current) {
        title = game.displayTitle
        creator = Self.creatorText(for: game)
        plays = Self.playsText(for: game, locale: locale)
        likes = Self.likesText(for: game, isLiked: isLiked, locale: locale)
        self.isLiked = isLiked
    }

    private static func creatorText(for game: Game) -> String? {
        guard let username = game.creatorUsername else {
            return nil
        }

        return "@\(username)"
    }

    private static func playsText(for game: Game, locale: Locale) -> String? {
        guard let plays = game.plays else {
            return nil
        }

        let count = shortNumber(plays, locale: locale)
        return String(localized: "\(count) plays")
    }

    /// The server's like count doesn't know about the user's own like, so it is added here.
    private static func likesText(for game: Game, isLiked: Bool, locale: Locale) -> String? {
        guard let serverLikes = game.likes else {
            return nil
        }

        var likes = serverLikes
        if isLiked {
            likes += 1
        }

        return shortNumber(likes, locale: locale)
    }

    /// A number written short, the way social apps do: 7855 → "7.9K", 285066 → "285K".
    private static func shortNumber(_ number: Int, locale: Locale) -> String {
        number.formatted(.number.locale(locale).notation(.compactName))
    }
}
