/// One batch of games from the server.
struct FeedPage: Equatable, Sendable {
    let games: [Game]
    /// The number of the page that comes next. `nil` means there are no more games.
    let nextPage: Int?
}
