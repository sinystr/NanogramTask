import Foundation
@testable import Nanogram

/// Answers every request the same way and remembers which URLs were asked for.
actor FakeHTTPClient: HTTPClientProtocol {
    private let answer: Answer
    private(set) var requestedURLs: [URL] = []

    init(answer: Answer) {
        self.answer = answer
    }

    func data(from url: URL) async throws -> (Data, URLResponse) {
        requestedURLs.append(url)
        switch answer {
        case .success(let body, let statusCode):
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        case .failure(let error):
            throw error
        }
    }
}
