import Foundation
import Testing
@testable import Nanogram

struct FeedErrorTests {
    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, FeedError.offline),
        (.networkConnectionLost, .offline),
        (.cannotFindHost, .offline),
        (.timedOut, .timedOut),
        (.badServerResponse, .server(statusCode: 0)),
        (.cannotParseResponse, .invalidData),
        (.unknown, .unknown),
    ])
    func mapsURLErrors(code: URLError.Code, expected: FeedError) {
        #expect(FeedError(URLError(code)) == expected)
    }

    @Test func keepsFeedErrorsAsIs() {
        #expect(FeedError(FeedError.server(statusCode: 502)) == .server(statusCode: 502))
    }

    @Test func mapsDecodingErrorsToInvalidData() {
        let error = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))
        #expect(FeedError(error) == .invalidData)
    }

    @Test(arguments: [FeedError.offline, .timedOut, .server(statusCode: 500), .invalidData, .unknown])
    func everyErrorHasUserFacingText(error: FeedError) {
        #expect(!error.title.isEmpty)
        #expect(!error.message.isEmpty)
    }
}
