import CoreGraphics

/// Where each feed position sits inside the scroll view.
///
/// The positions are stacked from top to bottom, and each one is exactly one screen tall.
/// Example, with a screen 800 points tall:
///
///     position 0 → top at y = 0
///     position 1 → top at y = 800
///     position 2 → top at y = 1600
struct GameScrollGeometry: Equatable {
    /// The size of one position: the size of the scroll view.
    let screenSize: CGSize

    init(screenSize: CGSize = .zero) {
        self.screenSize = screenSize
    }

    /// False until the screen size is known. Before that nothing can be placed.
    var isReady: Bool {
        let hasWidth = screenSize.width > 0
        let hasHeight = screenSize.height > 0
        return hasWidth && hasHeight
    }

    /// The size of the whole scrollable area: the scrollable positions stacked on top of each other.
    func contentSize(scrollablePositionCount: Int) -> CGSize {
        let count = max(scrollablePositionCount, 0)
        let totalHeight = CGFloat(count) * screenSize.height
        return CGSize(width: screenSize.width, height: totalHeight)
    }

    /// The rectangle that `position` fills inside the scrollable area.
    func frame(forPosition position: Int) -> CGRect {
        let topLeft = offset(forPosition: position)
        return CGRect(origin: topLeft, size: screenSize)
    }

    /// How far the scroll view must be scrolled to show `position`.
    func offset(forPosition position: Int) -> CGPoint {
        let top = CGFloat(position) * screenSize.height
        return CGPoint(x: 0, y: top)
    }

    /// The position that fills most of the screen when the scroll view is scrolled to `offsetY`.
    /// The result is always an existing position, even while the feed bounces past an end.
    func nearestPosition(toOffsetY offsetY: CGFloat, scrollablePositionCount: Int) -> Int {
        guard isReady, scrollablePositionCount > 0 else {
            return 0
        }

        // For example, 2.4 screens scrolled is closest to position 2, and 2.6 to position 3.
        let screensScrolled = offsetY / screenSize.height
        let nearest = Int(screensScrolled.rounded())

        let lastPosition = scrollablePositionCount - 1
        if nearest < 0 {
            return 0
        }

        if nearest > lastPosition {
            return lastPosition
        }

        return nearest
    }
}
