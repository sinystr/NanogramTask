import Foundation
import Testing
@testable import Nanogram

struct RemoteGameFeedServiceTests {
    private static let urlTemplate = "https://example.com/feed/page-{n}.json"
    private static let onePageJSON = """
        {
          "page": 3, "totalPages": 10, "nextPage": 4,
          "games": [{
            "id": "game-1",
            "title": "Nano Hole",
            "html": "<html></html>",
            "creator": { "username": "arnaud" },
            "stats": { "plays": 12, "likes": 5 }
          }]
        }
        """

    @Test func requestsTheURLOfThePageAndDecodesIt() async throws {
        let client = FakeHTTPClient(answer: .success(body: Self.onePageJSON, statusCode: 200))
        let service = RemoteGameFeedService(urlTemplate: Self.urlTemplate, client: client)
        
        let page = try await service.fetchPage(3)
        
        #expect(await client.requestedURLs == [URL(string: "https://example.com/feed/page-3.json")])
        #expect(page.nextPage == 4)
        #expect(page.games.map(\.id) == ["game-1"])
    }

    @Test(arguments: [404, 500, 503])
    func failingStatusCodeBecomesServerError(statusCode: Int) async {
        let client = FakeHTTPClient(answer: .success(body: Self.onePageJSON, statusCode: statusCode))
        let service = RemoteGameFeedService(urlTemplate: Self.urlTemplate, client: client)

        await #expect(throws: FeedError.server(statusCode: statusCode)) {
            try await service.fetchPage(1)
        }
    }

    @Test func unreadableBodyBecomesInvalidData() async {
        let client = FakeHTTPClient(answer: .success(body: "not json", statusCode: 200))
        let service = RemoteGameFeedService(urlTemplate: Self.urlTemplate, client: client)

        await #expect(throws: FeedError.invalidData) {
            try await service.fetchPage(1)
        }
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, FeedError.offline),
        (URLError.Code.timedOut, FeedError.timedOut),
    ])
    func networkErrorBecomesFeedError(code: URLError.Code, expected: FeedError) async {
        let client = FakeHTTPClient(answer: .failure(URLError(code)))
        let service = RemoteGameFeedService(urlTemplate: Self.urlTemplate, client: client)

        await #expect(throws: expected) {
            try await service.fetchPage(1)
        }
    }

    @Test func templateThatIsNotAURLBecomesUnknownError() async {
        let client = FakeHTTPClient(answer: .success(body: Self.onePageJSON, statusCode: 200))
        let service = RemoteGameFeedService(urlTemplate: "", client: client)

        await #expect(throws: FeedError.unknown) {
            try await service.fetchPage(1)
        }
        #expect(await client.requestedURLs.isEmpty)
    }
}
