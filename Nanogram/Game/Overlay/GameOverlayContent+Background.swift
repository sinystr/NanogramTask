extension GameOverlayContent {
    /// What is drawn behind the overlay's text.
    enum Background: Equatable {
        /// A still blue gradient, behind errors.
        case blueGradient

        /// Soft colored glows drifting slowly over a dark base, while something is on its way:
        /// a game, or more games.
        case driftingGlows
    }
}
