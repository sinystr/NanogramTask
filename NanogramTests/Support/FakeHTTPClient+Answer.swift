import Foundation

extension FakeHTTPClient {
    enum Answer {
        case success(body: String, statusCode: Int)
        case failure(URLError)
    }
}
