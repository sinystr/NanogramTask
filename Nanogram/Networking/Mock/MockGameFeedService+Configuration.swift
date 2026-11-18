#if DEBUG

extension MockGameFeedService {
    struct Configuration: Sendable {
        /// How many games each page has.
        let pageSize: Int
        /// How many pages the feed has. `nil` means the feed never ends.
        let totalPages: Int?
        /// How long each request takes, to act like a real network.
        let delay: Duration
        let failure: FailurePolicy

        init(
            pageSize: Int = 10,
            totalPages: Int? = nil,
            delay: Duration = .milliseconds(400),
            failure: FailurePolicy = .none
        ) {
            self.pageSize = pageSize
            self.totalPages = totalPages
            self.delay = delay
            self.failure = failure
        }
    }
}

#endif
