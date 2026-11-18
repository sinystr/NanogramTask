import Foundation
import os

extension FeedPage {
    /// Reads page number `page` of games from the server's JSON.
    ///
    /// Missing values don't fail the page: a missing game list is an empty page, and a game
    /// with missing values is still shown (a game without html shows an error and the user
    /// swipes on). Only JSON that can't be read at all throws.
    init(json: Data, page: Int) throws(FeedError) {
        do {
            let dto = try JSONDecoder().decode(FeedPageDTO.self, from: json)
            games = Self.games(from: dto, page: page)
            nextPage = Self.nextPage(from: dto, after: page)
        } catch {
            Log.network.error("Could not read the page of games: \(error.localizedDescription, privacy: .public)")
            throw .invalidData
        }
    }

    /// The page's games. A `null` entry becomes a game with every value missing, so the
    /// positions of the games after it don't shift.
    private static func games(from dto: FeedPageDTO, page: Int) -> [Game] {
        guard let entries = dto.games else {
            return []
        }

        var games: [Game] = []
        for (offset, entry) in entries.enumerated() {
            var gameDTO = GameDTO.empty
            if let entry {
                gameDTO = entry
            }

            let fallbackID = "page-\(page)-game-\(offset)"
            games.append(Game(dto: gameDTO, fallbackID: fallbackID))
        }

        return games
    }

    /// Only a page that really comes after `page` counts. A server that pointed back to the
    /// same or an earlier page would make the app load pages forever.
    private static func nextPage(from dto: FeedPageDTO, after page: Int) -> Int? {
        guard let next = dto.nextPage, next > page else {
            return nil
        }

        return next
    }
}
