import Foundation
import Testing
@testable import Nanogram

struct GameInfoBarContentTests {
    /// Numbers are written the US way here, whatever region the machine running the tests uses.
    private let locale = Locale(identifier: "en_US")

    private func makeGame(
        title: String? = "Nano Hole",
        creatorUsername: String? = "arnaud",
        plays: Int? = 285_066,
        likes: Int? = 7_855
    ) -> Game {
        Game(
            id: "g",
            title: title,
            html: "<html></html>",
            creatorUsername: creatorUsername,
            plays: plays,
            likes: likes
        )
    }

    @Test func showsTheGamesDetailsWithShortNumbers() {
        let content = GameInfoBarContent(game: makeGame(), isLiked: false, locale: locale)

        #expect(content.title == "Nano Hole")
        #expect(content.creator == "@arnaud")
        #expect(content.plays == "285K plays")
        #expect(content.likes == "7.9K")
        #expect(!content.isLiked)
    }

    @Test func theUsersOwnLikeIsCounted() {
        let content = GameInfoBarContent(game: makeGame(likes: 41), isLiked: true, locale: locale)

        #expect(content.likes == "42")
        #expect(content.isLiked)
    }

    @Test func missingValuesAreLeftOut() {
        let game = makeGame(title: nil, creatorUsername: nil, plays: nil, likes: nil)
        let content = GameInfoBarContent(game: game, isLiked: false, locale: locale)

        #expect(content.title == "Untitled game")
        #expect(content.creator == nil)
        #expect(content.plays == nil)
        #expect(content.likes == nil)
    }
}
