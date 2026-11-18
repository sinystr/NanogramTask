extension FeedViewModel {
    /// Whether more games are being loaded at the end of the feed, once it's showing.
    enum LoadMoreState: Equatable {
        case idle
        case loading
        case failed(FeedError)
    }
}
