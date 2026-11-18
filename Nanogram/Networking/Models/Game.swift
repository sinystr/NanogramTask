/// A game as the app uses it. It does not depend on how the server sends games.
///
/// The server can leave values out, so everything except `id` is optional.
struct Game: Identifiable, Hashable, Sendable {
    /// Always set. When the server leaves the id out, the app makes one up from the game's place.
    let id: String
    let title: String?
    /// The game's complete web page. It is loaded straight into a web view.
    /// A game without it shows "Couldn't load this game".
    let html: String?
    /// Who made the game. `nil` when the server doesn't say.
    let creatorUsername: String?
    let plays: Int?
    let likes: Int?
}
