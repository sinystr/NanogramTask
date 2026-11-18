import Foundation

/// Saves the user's likes on the device, in `UserDefaults`.
///
/// Likes are stored by game id, so a game keeps its like when the endless feed comes round to
/// it again, and after the app is relaunched.
@MainActor
final class LikedGamesStore: LikedGamesStoreProtocol {
    private static let key = "likedGameIDs"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadLikedGameIDs() -> Set<String> {
        guard let savedIDs = defaults.stringArray(forKey: Self.key) else {
            return []
        }

        return Set(savedIDs)
    }

    func saveLikedGameIDs(_ likedGameIDs: Set<String>) {
        // UserDefaults stores arrays, not sets. A set has no order, so sorting stores the same
        // likes the same way every time.
        let sortedIDs = likedGameIDs.sorted()
        defaults.set(sortedIDs, forKey: Self.key)
    }
}
