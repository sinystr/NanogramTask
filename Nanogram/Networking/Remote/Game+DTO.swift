extension Game {
    /// Makes an app game from the server's JSON shape.
    /// `fallbackID` is used when the server leaves the id out.
    init(dto: GameDTO, fallbackID: String) {
        var id = fallbackID
        if let serverID = dto.id {
            id = serverID
        }

        var creatorUsername: String?
        if let creator = dto.creator {
            creatorUsername = creator.username
        }

        var plays: Int?
        var likes: Int?
        if let stats = dto.stats {
            plays = stats.plays
            likes = stats.likes
        }

        self.init(
            id: id,
            title: dto.title,
            html: dto.html,
            creatorUsername: creatorUsername,
            plays: plays,
            likes: likes
        )
    }
}
