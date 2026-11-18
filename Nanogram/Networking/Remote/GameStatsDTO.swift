/// How popular a game is, shaped exactly like the server's JSON.
struct GameStatsDTO: Decodable {
    let plays: Int?
    let likes: Int?
}

extension GameStatsDTO {
    private enum CodingKeys: String, CodingKey {
        case plays, likes
    }

    /// Each number is read on its own. One of the wrong type becomes `nil`; the other is kept.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        plays = try? container.decodeIfPresent(Int.self, forKey: .plays)
        likes = try? container.decodeIfPresent(Int.self, forKey: .likes)
    }
}
