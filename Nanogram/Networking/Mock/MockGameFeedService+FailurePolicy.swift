#if DEBUG

extension MockGameFeedService {
    /// Which requests should fail.
    enum FailurePolicy: Sendable {
        /// Every request works.
        case none
        /// Every request fails.
        case always(FeedError)
        /// The first `count` requests fail (whatever page they ask for). Later ones work.
        case firstRequests(count: Int, error: FeedError)
        /// Requests for these pages fail. Other pages work.
        case pages(Set<Int>, error: FeedError)
    }
}

#endif
