import Foundation

/// Why a page of games could not be loaded, with text the app can show to the user.
enum FeedError: Error, Equatable, Sendable {
    case offline
    case timedOut
    case server(statusCode: Int)
    case invalidData
    case unknown

    /// Turns any error into a `FeedError`.
    init(_ error: any Error) {
        switch error {
        case let feedError as FeedError:
            self = feedError
        case is DecodingError:
            self = .invalidData
        case let urlError as URLError:
            self = FeedError(urlError: urlError)
        default:
            self = .unknown
        }
    }

    /// Turns a download error into a `FeedError`.
    private init(urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .internationalRoamingOff, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            self = .offline
        case .timedOut:
            self = .timedOut
        case .badServerResponse:
            // The server's answer was broken and had no usable status code.
            self = .server(statusCode: 0)
        case .cannotDecodeContentData, .cannotDecodeRawData, .cannotParseResponse, .zeroByteResource:
            self = .invalidData
        default:
            self = .unknown
        }
    }

    var title: String {
        switch self {
        case .offline: String(localized: "You're offline")
        case .timedOut: String(localized: "This is taking too long")
        case .server: String(localized: "Something went wrong on our side")
        case .invalidData: String(localized: "We couldn't read the games")
        case .unknown: String(localized: "Couldn't load games")
        }
    }

    var message: String {
        switch self {
        case .offline: String(localized: "Check your connection and try again.")
        case .timedOut: String(localized: "The server didn't respond in time. Please try again.")
        case .server: String(localized: "Our servers are having trouble. Please try again in a moment.")
        case .invalidData: String(localized: "The server sent something unexpected. Please try again.")
        case .unknown: String(localized: "Please try again.")
        }
    }
}
