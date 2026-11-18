import Foundation
import Testing
@testable import Nanogram

struct FeedPageDecodingTests {
    @Test func decodesTheDocumentedResponse() throws {
        let json = """
            {
              "page": 1, "totalPages": 10, "nextPage": 2,
              "games": [{
                "id": "986f54d8-fac5-47d5-ab2b-7e2b882f00ae",
                "title": "Nano Hole",
                "html": "<!DOCTYPE html><html></html>",
                "creator": { "username": "arnaud" },
                "stats": { "plays": 285066, "likes": 7855 }
              }]
            }
            """
        let page = try FeedPage(json: Data(json.utf8), page: 1)

        #expect(page.nextPage == 2)
        #expect(page.games == [
            Game(
                id: "986f54d8-fac5-47d5-ab2b-7e2b882f00ae",
                title: "Nano Hole",
                html: "<!DOCTYPE html><html></html>",
                creatorUsername: "arnaud",
                plays: 285_066,
                likes: 7_855
            ),
        ])
    }

    @Test(arguments: [#""creator": null,"#, ""])
    func gameWithoutACreatorStillDecodes(creatorField: String) throws {
        let json = """
            {
              "page": 1, "nextPage": 2,
              "games": [{
                "id": "g1", "title": "Nano Hole", "html": "<html></html>",
                \(creatorField)
                "stats": { "plays": 1, "likes": 2 }
              }]
            }
            """
        let page = try FeedPage(json: Data(json.utf8), page: 1)

        #expect(page.games.map(\.id) == ["g1"])
        #expect(page.games[0].creatorUsername == nil)
    }

    @Test func gameWithEveryValueMissingIsStillShown() throws {
        let json = #"{"nextPage": 3, "games": [{}]}"#
        let page = try FeedPage(json: Data(json.utf8), page: 2)

        #expect(page.nextPage == 3)
        #expect(page.games == [
            Game(id: "page-2-game-0", title: nil, html: nil, creatorUsername: nil, plays: nil, likes: nil),
        ])
    }

    @Test func valuesOfTheWrongTypeAreTreatedAsMissing() throws {
        let json = """
            {
              "nextPage": 2,
              "games": [{
                "id": 5, "title": ["Nano Hole"], "html": true,
                "creator": "arnaud",
                "stats": { "plays": "lots", "likes": 3 }
              }]
            }
            """
        let page = try FeedPage(json: Data(json.utf8), page: 1)

        #expect(page.nextPage == 2)
        #expect(page.games == [
            Game(id: "page-1-game-0", title: nil, html: nil, creatorUsername: nil, plays: nil, likes: 3),
        ])
    }

    @Test func creatorWithAWrongTypeUsernameIsKeptWithoutIt() throws {
        let json = #"{"games": [{"id": "g1", "creator": {"username": 42}}]}"#
        let page = try FeedPage(json: Data(json.utf8), page: 1)
        #expect(page.games[0].creatorUsername == nil)
    }

    @Test func entryThatIsNotAGameKeepsItsPlaceInThePage() throws {
        let json = #"{"games": ["oops", 7, {"id": "b"}]}"#
        let page = try FeedPage(json: Data(json.utf8), page: 1)
        #expect(page.games.map(\.id) == ["page-1-game-0", "page-1-game-1", "b"])
    }

    @Test func nullGameKeepsItsPlaceInThePage() throws {
        let json = #"{"games": [null, {"id": "b"}]}"#
        let page = try FeedPage(json: Data(json.utf8), page: 1)
        #expect(page.games.map(\.id) == ["page-1-game-0", "b"])
    }

    @Test func missingGamesMeansAnEmptyPage() throws {
        let json = #"{"nextPage": 2, "games": null}"#
        let page = try FeedPage(json: Data(json.utf8), page: 1)

        #expect(page.games.isEmpty)
        #expect(page.nextPage == 2)
    }

    @Test func emptyResponseIsAnEmptyLastPage() throws {
        let page = try FeedPage(json: Data("{}".utf8), page: 1)

        #expect(page.games.isEmpty)
        #expect(page.nextPage == nil)
    }

    @Test func lastPageHasNoNextPage() throws {
        let json = #"{"page": 10, "totalPages": 10, "nextPage": null, "games": []}"#
        #expect(try FeedPage(json: Data(json.utf8), page: 10).nextPage == nil)
    }

    @Test func nextPageThatDoesNotMoveForwardEndsTheFeed() throws {
        let json = #"{"page": 3, "totalPages": 10, "nextPage": 3, "games": []}"#
        #expect(try FeedPage(json: Data(json.utf8), page: 3).nextPage == nil)
    }

    @Test func malformedPayloadThrowsInvalidData() {
        #expect(throws: FeedError.invalidData) {
            try FeedPage(json: Data(#"{"page": "one"}"#.utf8), page: 1)
        }
    }
}
