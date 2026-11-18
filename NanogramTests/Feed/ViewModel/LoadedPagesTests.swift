import Testing
@testable import Nanogram

struct LoadedPagesTests {
    @Test func appendsPagesBackToBack() {
        let pages = LoadedPages()
            .appending(page: 1, gameCount: 10)
            .appending(page: 2, gameCount: 7)

        #expect(pages.gameIndices(of: 1) == 0..<10)
        #expect(pages.gameIndices(of: 2) == 10..<17)
        #expect(pages.gameCount == 17)
    }

    @Test func appendingReturnsANewValueAndLeavesTheOldOneAlone() {
        let empty = LoadedPages()
        let withOnePage = empty.appending(page: 1, gameCount: 10)

        #expect(empty.gameCount == 0)
        #expect(withOnePage.gameCount == 10)
    }

    @Test func findsThePageContainingAGameIndex() {
        let pages = LoadedPages()
            .appending(page: 1, gameCount: 10)
            .appending(page: 2, gameCount: 7)
            .appending(page: 3, gameCount: 10)

        #expect(pages.page(containing: 0) == 1)
        #expect(pages.page(containing: 9) == 1)
        #expect(pages.page(containing: 10) == 2)
        #expect(pages.page(containing: 16) == 2)
        #expect(pages.page(containing: 17) == 3)
        #expect(pages.page(containing: 27) == nil)
        #expect(pages.page(containing: -1) == nil)
        #expect(pages.gameIndicesOfPage(containing: 12) == 10..<17)
    }

    @Test func emptyPagesCoverNothing() {
        let pages = LoadedPages()
            .appending(page: 1, gameCount: 5)
            .appending(page: 2, gameCount: 0)
            .appending(page: 3, gameCount: 5)

        #expect(pages.gameIndices(of: 2) == 5..<5)
        #expect(pages.page(containing: 5) == 3)
    }

    @Test func appendingTheSamePageTwiceIsIgnored() {
        let pages = LoadedPages()
            .appending(page: 1, gameCount: 10)
            .appending(page: 1, gameCount: 10)

        #expect(pages.gameIndices(of: 1) == 0..<10)
        #expect(pages.gameCount == 10)
    }

    @Test func unknownPageHasNoGameIndices() {
        let pages = LoadedPages().appending(page: 1, gameCount: 10)

        #expect(pages.gameIndices(of: 2) == nil)
    }
}
