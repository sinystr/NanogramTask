import CoreGraphics
import Testing
@testable import Nanogram

struct PositionSlotsTests {
    private func arranged(around middlePosition: Int, scrollablePositionCount: Int) -> PositionSlots {
        PositionSlots().arranged(around: middlePosition, scrollablePositionCount: scrollablePositionCount)
    }

    /// Every expected position is shown by exactly one slot, and nothing else is shown.
    private func expectShows(_ slots: PositionSlots, _ expected: Set<Int>, sourceLocation: SourceLocation = #_sourceLocation) {
        let shown = slots.positionInEachSlot.compactMap { $0 }
        #expect(Set(shown) == expected, sourceLocation: sourceLocation)
        #expect(shown.count == Set(shown).count, "a position is shown twice", sourceLocation: sourceLocation)
    }

    /// The slots that show a different position than before.
    private func changedSlots(from before: PositionSlots, to after: PositionSlots) -> [Int] {
        let slotIndices = before.positionInEachSlot.indices
        return slotIndices.filter { before.positionInEachSlot[$0] != after.positionInEachSlot[$0] }
    }

    @Test func firstArrangementFillsPreviousCurrentAndNext() {
        let slots = arranged(around: 5, scrollablePositionCount: 20)
        #expect(changedSlots(from: PositionSlots(), to: slots) == [0, 1, 2])
        expectShows(slots, [4, 5, 6])
    }

    @Test func movingForwardOnePositionRebindsOnlyOneView() {
        let before = arranged(around: 5, scrollablePositionCount: 20)
        let after = before.arranged(around: 6, scrollablePositionCount: 20)

        let changed = changedSlots(from: before, to: after)
        #expect(changed.count == 1)
        let slot = changed[0]
        #expect(before.positionInEachSlot[slot] == 4) // the view that showed the old previous position...
        #expect(after.positionInEachSlot[slot] == 7) // ...now shows the new next position
        expectShows(after, [5, 6, 7])
    }

    @Test func movingBackOnePositionRebindsOnlyOneView() {
        let before = arranged(around: 5, scrollablePositionCount: 20)
        let after = before.arranged(around: 4, scrollablePositionCount: 20)
        #expect(changedSlots(from: before, to: after).count == 1)
        expectShows(after, [3, 4, 5])
    }

    @Test func jumpingTwoPositionsKeepsTheOverlappingView() {
        let before = arranged(around: 5, scrollablePositionCount: 20)
        let after = before.arranged(around: 7, scrollablePositionCount: 20)

        #expect(changedSlots(from: before, to: after).count == 2)
        #expect(after.positionInEachSlot.firstIndex(of: 6) == before.positionInEachSlot.firstIndex(of: 6))
        expectShows(after, [6, 7, 8])
    }

    @Test func jumpingFarRebindsAllViews() {
        let before = arranged(around: 5, scrollablePositionCount: 20)
        let after = before.arranged(around: 15, scrollablePositionCount: 20)
        #expect(changedSlots(from: before, to: after).count == 3)
        expectShows(after, [14, 15, 16])
    }

    @Test func atTheFirstPositionOnlyTwoViewsAreUsed() {
        let slots = arranged(around: 0, scrollablePositionCount: 20)
        expectShows(slots, [0, 1])
    }

    @Test func atTheLastPositionOnlyTwoViewsAreUsed() {
        let slots = arranged(around: 19, scrollablePositionCount: 20)
        expectShows(slots, [18, 19])
    }

    @Test func loadMorePositionIsLaidOutLikeAnyOtherPosition() {
        // 20 games + the load-more position = 21 positions; the load-more position is the last one.
        var slots = arranged(around: 19, scrollablePositionCount: 21)
        expectShows(slots, [18, 19, 20])

        slots = slots.arranged(around: 20, scrollablePositionCount: 21)
        expectShows(slots, [19, 20])
    }

    @Test func loadMorePositionAppearingAddsTheNextPositionWithoutMovingOthers() {
        let before = arranged(around: 19, scrollablePositionCount: 20)
        let after = before.arranged(around: 19, scrollablePositionCount: 21)

        let changed = changedSlots(from: before, to: after)
        #expect(changed.count == 1)
        #expect(before.positionInEachSlot[changed[0]] == nil)
        expectShows(after, [18, 19, 20])
    }

    @Test func singlePositionFeed() {
        let slots = arranged(around: 0, scrollablePositionCount: 1)
        expectShows(slots, [0])
    }

    @Test func emptyFeedShowsNothing() {
        let slots = arranged(around: 3, scrollablePositionCount: 10).arranged(around: 0, scrollablePositionCount: 0)
        expectShows(slots, [])
    }

    @Test func rearrangingInPlaceChangesNothing() {
        let before = arranged(around: 5, scrollablePositionCount: 20)
        let after = before.arranged(around: 5, scrollablePositionCount: 20)
        #expect(after == before)
    }

    @Test func fastFlicksNeverDuplicateOrLoseAPosition() {
        var slots = PositionSlots()
        let path = [0, 1, 2, 3, 2, 3, 4, 5, 6, 5, 4, 8, 9, 0, 1]
        let scrollablePositions = 0..<10
        for middlePosition in path {
            slots = slots.arranged(around: middlePosition, scrollablePositionCount: scrollablePositions.count)

            let nearbyPositions = (middlePosition - 1)...(middlePosition + 1)
            let expected = Set(nearbyPositions.filter { scrollablePositions.contains($0) })
            expectShows(slots, expected)
        }
    }
}
