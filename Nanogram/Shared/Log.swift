import Foundation
import os

/// The app's loggers, one per area, so the Console app and Instruments can show one area at a time.
enum Log {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "Nanogram"

    static let feed = Logger(subsystem: subsystem, category: "feed")
    static let game = Logger(subsystem: subsystem, category: "game")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let lifecycle = Logger(subsystem: subsystem, category: "lifecycle")

    /// Measures how long games take to load. The results show up in Instruments.
    static let gameSignposter = OSSignposter(subsystem: subsystem, category: "game")
}
