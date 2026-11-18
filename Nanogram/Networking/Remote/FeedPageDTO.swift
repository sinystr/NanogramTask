/// One page of games, shaped exactly like the server's JSON.
///
/// The DTO types are kept apart from `Game` and `FeedPage`, so a change in the server's format
/// only needs changes in the DTO files and `FeedPage+JSON.swift`.
///
/// The server can return `null` for any value or leave it out, so every field is optional.
struct FeedPageDTO: Decodable {
    let page: Int?
    let nextPage: Int?
    /// A `nil` entry means the server returned `null` in place of a game.
    let games: [GameDTO?]?
}
