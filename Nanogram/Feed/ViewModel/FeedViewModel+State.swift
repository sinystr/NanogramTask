extension FeedViewModel {
    enum State: Equatable {
        case loadingFirstPage
        case failedInitial(FeedError)
        case loaded(loadMore: LoadMoreState)
    }
}
