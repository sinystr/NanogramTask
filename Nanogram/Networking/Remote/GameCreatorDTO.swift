/// Who made a game, shaped exactly like the server's JSON.
struct GameCreatorDTO: Decodable {
    let username: String?
}

extension GameCreatorDTO {
    private enum CodingKeys: String, CodingKey {
        case username
    }

    /// A username of the wrong type becomes `nil`.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        username = try? container.decodeIfPresent(String.self, forKey: .username)
    }
}
