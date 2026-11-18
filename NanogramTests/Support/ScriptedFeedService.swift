@testable import Nanogram

/// Serves fixed pages that a test can swap out, e.g. to make a page shrink between fetches.
actor ScriptedFeedService: GameFeedServiceProtocol {
    private var pages: [Int: FeedPage]
    private let delay: Duration
    private(set) var requestedPages: [Int] = []

    init(pages: [Int: FeedPage], delay: Duration = .zero) {
        self.pages = pages
        self.delay = delay
    }

    func replace(page: Int, with feedPage: FeedPage) {
        pages[page] = feedPage
    }

    func fetchPage(_ page: Int) async throws -> FeedPage {
        requestedPages.append(page)
        try await Task.sleep(for: delay)

        guard let feedPage = pages[page] else {
            throw FeedError.server(statusCode: 404)
        }

        return feedPage
    }
}
