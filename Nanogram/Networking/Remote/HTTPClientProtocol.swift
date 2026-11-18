import Foundation

/// Something that can download the data behind a URL.
/// The app uses `URLSession`. Tests use a fake.
protocol HTTPClientProtocol: Sendable {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClientProtocol {}
