/// What the feed's view model needs from the thing that downloads API pages.
@MainActor
protocol PageDownloaderProtocol: AnyObject {
    /// The page being downloaded right now, or `nil` when nothing is downloading.
    var downloadingPage: Int? { get }

    /// Starts downloading `page` and calls `onResult` when it's done.
    /// Does nothing if a download is already running.
    func download(_ page: Int, onResult: @escaping @MainActor (Result<FeedPage, FeedError>) -> Void)

    /// Stops the running download. Its `onResult` is never called.
    func cancel()
}
