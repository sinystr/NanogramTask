/// The API pages loaded so far, and which game indices each one covered.
///
/// It holds no games, only page numbers and their game indices. When a game was removed from
/// memory, this tells us which API page to download to get it back. It stores the number of
/// games each page really had, so pages may differ in size.
///
/// Example, after loading pages with 10, 10 and 4 games:
///
///     page 1 → game indices 0..<10
///     page 2 → game indices 10..<20
///     page 3 → game indices 20..<24
///
/// It never changes. `appending(page:gameCount:)` returns a new value with one more page.
struct LoadedPages: Equatable {
    private struct PageRecord: Equatable {
        let page: Int
        let gameIndices: Range<Int>
    }

    /// One record per loaded page, in the order the pages were loaded.
    private let records: [PageRecord]

    /// No pages loaded yet.
    init() {
        records = []
    }

    private init(records: [PageRecord]) {
        self.records = records
    }

    /// Total number of games across all loaded pages.
    var gameCount: Int {
        guard let lastRecord = records.last else {
            return 0
        }

        return lastRecord.gameIndices.upperBound
    }

    /// A new value with `page` added right after the last loaded page.
    /// If `page` is already loaded, the value is returned as it is.
    func appending(page: Int, gameCount newGameCount: Int) -> LoadedPages {
        if gameIndices(of: page) != nil {
            return self
        }

        let firstIndex = gameCount
        let newRecord = PageRecord(page: page, gameIndices: firstIndex..<(firstIndex + newGameCount))
        return LoadedPages(records: records + [newRecord])
    }

    /// The game indices that `page` covers, or `nil` if the page was never loaded.
    func gameIndices(of page: Int) -> Range<Int>? {
        for record in records where record.page == page {
            return record.gameIndices
        }

        return nil
    }

    /// The API page that the game at `gameIndex` came from.
    func page(containing gameIndex: Int) -> Int? {
        guard let record = record(containing: gameIndex) else {
            return nil
        }

        return record.page
    }

    /// True if at least one game of `page` is among `gameIndices`.
    /// For example: is any game of this page still kept in memory?
    func pageHasGame(_ page: Int, in indicesToCheck: Set<Int>) -> Bool {
        guard let pageGameIndices = gameIndices(of: page) else {
            return false
        }

        return !indicesToCheck.isDisjoint(with: pageGameIndices)
    }

    /// All game indices of the API page that the game at `gameIndex` came from.
    func gameIndicesOfPage(containing gameIndex: Int) -> Range<Int>? {
        guard let record = record(containing: gameIndex) else {
            return nil
        }

        return record.gameIndices
    }

    private func record(containing gameIndex: Int) -> PageRecord? {
        for record in records where record.gameIndices.contains(gameIndex) {
            return record
        }

        return nil
    }
}
