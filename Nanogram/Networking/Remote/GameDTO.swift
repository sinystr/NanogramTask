/// One game, shaped exactly like the server's JSON.
/// The server can return `null` for any value, leave it out, or send a value of another type.
struct GameDTO: Decodable {
    /// A game with every value missing. Used when the server returns `null` or something
    /// that isn't a game object in place of a game.
    static let empty = GameDTO(id: nil, title: nil, html: nil, creator: nil, stats: nil)

    let id: String?
    let title: String?
    let html: String?
    let creator: GameCreatorDTO?
    let stats: GameStatsDTO?
}

// Written in an extension, so Swift still makes the memberwise init that `empty` uses.
extension GameDTO {
    private enum CodingKeys: String, CodingKey {
        case id, title, html, creator, stats
    }

    /// Reads each value on its own. A value of the wrong type becomes `nil`, so one bad
    /// value never fails the game or the page. Something that isn't a game object at all
    /// becomes `empty`.
    init(from decoder: any Decoder) throws {
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self = .empty
            return
        }
        id = try? container.decodeIfPresent(String.self, forKey: .id)
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        html = try? container.decodeIfPresent(String.self, forKey: .html)
        creator = try? container.decodeIfPresent(GameCreatorDTO.self, forKey: .creator)
        stats = try? container.decodeIfPresent(GameStatsDTO.self, forKey: .stats)
    }
}
