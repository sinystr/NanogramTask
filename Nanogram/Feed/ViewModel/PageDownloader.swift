/// Downloads one API page at a time and hands the result back on the main actor.
///
/// It is `@MainActor` because its only user, the feed's view model, is: the view model can
/// check and start downloads with plain calls, no `await`. The slow part, the network request
/// and the JSON decoding, runs off the main actor in `fetch`.
///
/// A cancelled download never calls back, because whoever started it has moved on.
@MainActor
final class PageDownloader: PageDownloaderProtocol {
    private let service: any GameFeedServiceProtocol
    /// The download in progress, if any.
    private var runningDownload: (page: Int, task: Task<Void, Never>)?

    init(service: any GameFeedServiceProtocol) {
        self.service = service
    }

    var downloadingPage: Int? {
        guard let runningDownload else {
            return nil
        }

        return runningDownload.page
    }

    func download(_ page: Int, onResult: @escaping @MainActor (Result<FeedPage, FeedError>) -> Void) {
        guard runningDownload == nil else {
            return
        }

        let task = Task { [weak self, service] in
            let result = await Self.fetch(page, from: service)
            guard !Task.isCancelled, let self else {
                return
            }

            // Cleared before calling back, so the caller can start the next download right away.
            runningDownload = nil
            onResult(result)
        }

        runningDownload = (page, task)
    }

    func cancel() {
        guard let runningDownload else {
            return
        }

        runningDownload.task.cancel()
        self.runningDownload = nil
    }

    /// Runs off the main actor. Any error becomes a `FeedError` the user can be shown.
    private nonisolated static func fetch(
        _ page: Int,
        from service: any GameFeedServiceProtocol
    ) async -> Result<FeedPage, FeedError> {
        do {
            return .success(try await service.fetchPage(page))
        } catch {
            return .failure(FeedError(error))
        }
    }
}
