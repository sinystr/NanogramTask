@testable import Nanogram

extension MockGameFeedService.Configuration {
    static func test(
        pageSize: Int = 10,
        totalPages: Int? = nil,
        delay: Duration = .zero,
        failure: MockGameFeedService.FailurePolicy = .none
    ) -> Self {
        Self(pageSize: pageSize, totalPages: totalPages, delay: delay, failure: failure)
    }
}
