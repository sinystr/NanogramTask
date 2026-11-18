@testable import Nanogram

/// Keeps likes in memory instead of on the device, so tests never touch real saved likes.
@MainActor
final class InMemoryLikedGamesStore: LikedGamesStoreProtocol {
    /// What was saved last, so tests can check it.
    private(set) var savedLikedGameIDs: Set<String>

    /// `likedGameIDs` acts like likes saved during an earlier launch.
    init(likedGameIDs: Set<String> = []) {
        savedLikedGameIDs = likedGameIDs
    }

    func loadLikedGameIDs() -> Set<String> {
        savedLikedGameIDs
    }

    func saveLikedGameIDs(_ likedGameIDs: Set<String>) {
        savedLikedGameIDs = likedGameIDs
    }
}
