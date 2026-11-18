import CoreGraphics
import Testing
@testable import Nanogram

struct GameScrollGeometryTests {
    private let geometry = GameScrollGeometry(screenSize: CGSize(width: 390, height: 844))

    @Test func positionsStackVertically() {
        #expect(geometry.frame(forPosition: 3) == CGRect(x: 0, y: 3 * 844, width: 390, height: 844))
        #expect(geometry.contentSize(scrollablePositionCount: 21) == CGSize(width: 390, height: 21 * 844))
    }

    @Test func nearestPositionRoundsToTheClosestOne() {
        #expect(geometry.nearestPosition(toOffsetY: 844 * 2.4, scrollablePositionCount: 10) == 2)
        #expect(geometry.nearestPosition(toOffsetY: 844 * 2.6, scrollablePositionCount: 10) == 3)
    }

    @Test func nearestPositionIsClampedDuringBounces() {
        #expect(geometry.nearestPosition(toOffsetY: -200, scrollablePositionCount: 10) == 0)
        #expect(geometry.nearestPosition(toOffsetY: 844 * 12, scrollablePositionCount: 10) == 9)
    }

    @Test func notReadyBeforeTheFirstLayout() {
        let empty = GameScrollGeometry()
        #expect(!empty.isReady)
        #expect(empty.nearestPosition(toOffsetY: 500, scrollablePositionCount: 10) == 0)
    }
}
