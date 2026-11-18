import Foundation
import os

/// Downloads pages of games from the real server. Each page is one JSON file.
struct RemoteGameFeedService: GameFeedServiceProtocol {
    /// The address of a page. `{n}` is replaced with the page number.
    static let defaultURLTemplate = "https://gist.githubusercontent.com/jimagination/caed8b3e0e5d17a01a4d06cfc07dd362/raw/page-{n}.json"
    private static let requestTimeoutInSeconds: TimeInterval = 15

    private let urlTemplate: String
    private let client: any HTTPClientProtocol

    init(
        urlTemplate: String = RemoteGameFeedService.defaultURLTemplate,
        client: any HTTPClientProtocol = RemoteGameFeedService.makeDefaultClient()
    ) {
        self.urlTemplate = urlTemplate
        self.client = client
    }

    func fetchPage(_ page: Int) async throws -> FeedPage {
        let address = urlTemplate.replacingOccurrences(of: "{n}", with: String(page))
        guard let url = URL(string: address) else {
            Log.network.error("Could not build a URL for page \(page)")
            throw FeedError.unknown
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await client.data(from: url)
        } catch {
            // If the download was cancelled on purpose, report that and not a failure.
            try Task.checkCancellation()
            Log.network.error("Download failed: \(error.localizedDescription, privacy: .public)")
            throw FeedError(error)
        }

        if let httpResponse = response as? HTTPURLResponse {
            let statusCode = httpResponse.statusCode
            let isSuccess = (200..<300).contains(statusCode)
            if !isSuccess {
                Log.network.error("Server answered with status \(statusCode)")
                throw FeedError.server(statusCode: statusCode)
            }
        }
        return try FeedPage(json: data, page: page)
    }

    static func makeDefaultClient() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeoutInSeconds
        // When offline, fail right away so the user sees an error with Retry
        // and not a spinner that never ends.
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
