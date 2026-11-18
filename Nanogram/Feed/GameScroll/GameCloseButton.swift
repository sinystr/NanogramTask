import UIKit

/// The round "X" button that ends play mode. It starts hidden.
final class GameCloseButton: UIButton, GameCloseButtonProtocol {
    private enum Style {
        static let spacingFromTop: CGFloat = 8
        static let spacingFromSide: CGFloat = 16
        static let minimumTapSize: CGFloat = 44
        static let backgroundOpacity: CGFloat = 0.55
    }

    init() {
        super.init(frame: .zero)
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "xmark")
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = .black.withAlphaComponent(Style.backgroundOpacity)
        configuration.baseForegroundColor = .white
        self.configuration = configuration

        accessibilityIdentifier = "game.close"
        isHidden = true
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Pins the button to the top right corner of `guide`. Call it after adding the button
    /// to a view.
    func placeInTopRightCorner(of guide: UILayoutGuide) {
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: guide.topAnchor, constant: Style.spacingFromTop),
            trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -Style.spacingFromSide),
            widthAnchor.constraint(greaterThanOrEqualToConstant: Style.minimumTapSize),
            heightAnchor.constraint(greaterThanOrEqualToConstant: Style.minimumTapSize),
        ])
    }
}
