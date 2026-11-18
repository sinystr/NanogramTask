/// Decides which feed position each of the reusable game views shows.
///
/// Each game view has a slot. The slots cover the previous, current and next position. A slot
/// keeps its position for as long as that position is still shown, so moving by one position
/// changes only one view.
///
/// The slots never change. `arranged(around:scrollablePositionCount:)` returns new slots.
struct PositionSlots: Equatable {
    /// How many positions are kept ready before and after the middle one.
    private static let positionsOnEachSide = 1
    /// Number of slots, which is the number of game views: the middle position plus the
    /// positions on each side.
    static let slotCount = 1 + 2 * positionsOnEachSide

    /// The feed position each slot shows. `nil` means that slot's view has nothing to show.
    let positionInEachSlot: [Int?]

    /// No slot shows anything yet.
    init() {
        positionInEachSlot = Array(repeating: nil, count: Self.slotCount)
    }

    private init(positionInEachSlot: [Int?]) {
        self.positionInEachSlot = positionInEachSlot
    }

    /// New slots with the views placed around `middlePosition`, using only positions the user
    /// can scroll to (`0..<scrollablePositionCount`).
    func arranged(around middlePosition: Int, scrollablePositionCount: Int) -> PositionSlots {
        let positionsToShow = Self.positionsToShow(
            around: middlePosition,
            scrollablePositionCount: scrollablePositionCount
        )

        // Step 1: a slot that already shows a position to show keeps it. Every other slot is freed.
        var newPositionInEachSlot: [Int?] = []
        for position in positionInEachSlot {
            if let position, positionsToShow.contains(position) {
                newPositionInEachSlot.append(position)
            } else {
                newPositionInEachSlot.append(nil)
            }
        }

        // Step 2: each position to show that has no slot yet goes to the first free slot.
        for position in positionsToShow where !newPositionInEachSlot.contains(position) {
            if let freeSlot = newPositionInEachSlot.firstIndex(of: nil) {
                newPositionInEachSlot[freeSlot] = position
            }
        }

        return PositionSlots(positionInEachSlot: newPositionInEachSlot)
    }

    /// The middle position and the positions on each side of it, leaving out positions the user
    /// can't scroll to.
    private static func positionsToShow(around middlePosition: Int, scrollablePositionCount: Int) -> [Int] {
        let first = middlePosition - positionsOnEachSide
        let last = middlePosition + positionsOnEachSide
        let scrollablePositions = 0..<scrollablePositionCount
        return (first...last).filter { scrollablePositions.contains($0) }
    }
}
