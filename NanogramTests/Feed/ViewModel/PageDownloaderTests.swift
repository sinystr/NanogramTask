import Testing
@testable import Nanogram

@MainActor
struct PageDownloaderTests {
    /// Remembers what a download reported, so a test can check it.
    @MainActor
    private final class ResultRecorder {
        var result: Result<FeedPage, FeedError>?
    }

    @Test func downloadsAPageAndCallsBack() async {
        let service = MockGameFeedService(configuration: .test())
        let downloader = PageDownloader(service: service)
        let recorder = ResultRecorder()

        downloader.download(1) { recorder.result = $0 }
        #expect(downloader.downloadingPage == 1)

        await waitUntil { recorder.result != nil }
        #expect(downloader.downloadingPage == nil)

        guard case .success(let page) = recorder.result else {
            Issue.record("Expected a downloaded page, got \(String(describing: recorder.result))")
            return
        }

        #expect(page.games.count == 10)
    }

    @Test func onlyOneDownloadRunsAtATime() async {
        let service = MockGameFeedService(configuration: .test(delay: .milliseconds(100)))
        let downloader = PageDownloader(service: service)
        let recorder = ResultRecorder()

        downloader.download(1) { recorder.result = $0 }
        downloader.download(2) { _ in }

        #expect(downloader.downloadingPage == 1)
        await waitUntil { recorder.result != nil }
        #expect(await service.requestedPages == [1])
    }

    @Test func aCancelledDownloadNeverCallsBack() async throws {
        let service = MockGameFeedService(configuration: .test(delay: .milliseconds(100)))
        let downloader = PageDownloader(service: service)
        let recorder = ResultRecorder()

        downloader.download(1) { recorder.result = $0 }
        downloader.cancel()

        #expect(downloader.downloadingPage == nil)
        try await Task.sleep(for: .milliseconds(300))
        #expect(recorder.result == nil)
    }

    @Test func aFailedDownloadReportsAFeedError() async {
        let service = MockGameFeedService(configuration: .test(failure: .always(.offline)))
        let downloader = PageDownloader(service: service)
        let recorder = ResultRecorder()

        downloader.download(1) { recorder.result = $0 }
        await waitUntil { recorder.result != nil }

        #expect(recorder.result == .failure(.offline))
    }
}
