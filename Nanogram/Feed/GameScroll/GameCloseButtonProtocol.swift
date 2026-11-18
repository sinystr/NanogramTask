import UIKit

/// What the game scroll screen needs from the button that ends play mode.
@MainActor
protocol GameCloseButtonProtocol: UIButton {
    /// Pins the button to the top right corner of `guide`. Call it after adding the button
    /// to a view.
    func placeInTopRightCorner(of guide: UILayoutGuide)
}
