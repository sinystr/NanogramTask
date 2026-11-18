import Foundation

/// Something that can download pages of games.
protocol GameFeedServiceProtocol: Sendable {
    /// Downloads one page of games. Page numbers start at 1.
    /// - Throws: `FeedError`, or `CancellationError` if the calling task was cancelled.
    func fetchPage(_ page: Int) async throws -> FeedPage
}
