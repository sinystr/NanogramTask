import UIKit

/// Shows a `GameOverlayContent` over a game view.
final class GameOverlayView: UIView, GameOverlayViewProtocol {
    private static let spacingBetweenItems: CGFloat = 12

    /// The blue gradient behind errors, from Apple's blue at the top to a deeper blue at the
    /// bottom. The drifting glows cover it while something is loading.
    private enum BackgroundGradient {
        static let topColor = UIColor(red: 0 / 255, green: 122 / 255, blue: 255 / 255, alpha: 1)
        static let bottomColor = UIColor(red: 0 / 255, green: 64 / 255, blue: 221 / 255, alpha: 1)
    }

    /// Makes the view draw a gradient instead of a single background color.
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    /// Called when the user taps Retry.
    var onRetry: (() -> Void)?

    private let driftingGlows = DriftingGlowsView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let retryButton = UIButton(configuration: .filled())

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "game.overlay"
        setUpBackground()
        setUpDriftingGlows()
        setUpLabels()
        setUpSpinnerAndRetryButton()
        setUpLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func setUpBackground() {
        if let gradientLayer = layer as? CAGradientLayer {
            gradientLayer.colors = [BackgroundGradient.topColor.cgColor, BackgroundGradient.bottomColor.cgColor]
        }
    }

    /// Covers the blue gradient while something is loading. Hidden otherwise.
    private func setUpDriftingGlows() {
        driftingGlows.isHidden = true
        driftingGlows.frame = bounds
        driftingGlows.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(driftingGlows)
    }

    private func setUpLabels() {
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        detailLabel.font = .preferredFont(forTextStyle: .body)
        for label in [titleLabel, detailLabel] {
            label.textColor = .white
            label.textAlignment = .center
            label.numberOfLines = 0 // 0 means "as many lines as the text needs".
        }
    }

    private func setUpSpinnerAndRetryButton() {
        spinner.color = .white
        retryButton.configuration?.title = String(localized: "Retry")
        retryButton.accessibilityIdentifier = "game.retry"
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)
    }

    /// Stacks everything vertically in the middle of the view.
    private func setUpLayout() {
        let stack = UIStackView(arrangedSubviews: [spinner, titleLabel, detailLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Self.spacingBetweenItems
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
        ])
    }

    // MARK: - Showing content

    func show(_ content: GameOverlayContent) {
        titleLabel.text = content.title
        titleLabel.isHidden = content.title == nil
        detailLabel.text = content.detail
        detailLabel.isHidden = content.detail == nil
        retryButton.isHidden = !content.showsRetry
        spinner.isHidden = !content.showsSpinner
        if content.showsSpinner {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }

        let showsDriftingGlows = content.background == .driftingGlows
        driftingGlows.isHidden = !showsDriftingGlows
        driftingGlows.setDrifting(showsDriftingGlows)
    }
}

/// Soft violet, pink and cyan glows drifting slowly over a dark indigo base.
private final class DriftingGlowsView: UIView {
    /// One colored glow and the path it drifts along.
    private struct Glow {
        let color: UIColor

        /// Where the glow's center starts and where it drifts to, as fractions of the view's size.
        let start: CGPoint
        let end: CGPoint

        /// Seconds for one drift. Each glow takes a different time, so they never line up the same way.
        let driftDuration: CFTimeInterval
    }

    private enum Palette {
        static let baseTop = UIColor(red: 0.07, green: 0.05, blue: 0.18, alpha: 1)
        static let baseBottom = UIColor(red: 0.01, green: 0.01, blue: 0.05, alpha: 1)
        static let violet = UIColor(red: 0.49, green: 0.23, blue: 0.93, alpha: 1)
        static let pink = UIColor(red: 0.93, green: 0.28, blue: 0.60, alpha: 1)
        static let cyan = UIColor(red: 0.02, green: 0.71, blue: 0.83, alpha: 1)
    }

    private static let glows = [
        Glow(color: Palette.violet, start: CGPoint(x: 0.15, y: 0.2), end: CGPoint(x: 0.8, y: 0.4), driftDuration: 7),
        Glow(color: Palette.pink, start: CGPoint(x: 0.9, y: 0.75), end: CGPoint(x: 0.25, y: 0.85), driftDuration: 9),
        Glow(color: Palette.cyan, start: CGPoint(x: 0.4, y: 1.0), end: CGPoint(x: 0.6, y: 0.1), driftDuration: 11),
    ]

    /// How wide each glow is, compared with the view's width.
    private static let glowWidthToViewWidth: CGFloat = 1.4

    /// How strong a glow is at its center. It fades to nothing at its edge.
    private static let glowCenterOpacity: CGFloat = 0.7

    /// Makes the view draw the dark base as a gradient.
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    private var glowLayers: [CAGradientLayer] = []
    private var isDrifting = false

    /// The size the glows were last placed for.
    private var placedForSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        setUpBase()
        setUpGlows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Starts or stops the drifting glows. They move only while they are shown, and never when
    /// the user asked for reduced motion.
    func setDrifting(_ drifting: Bool) {
        guard drifting != isDrifting else {
            return
        }

        isDrifting = drifting
        restartDrifting()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != placedForSize else {
            return
        }

        placedForSize = bounds.size
        placeGlows()

        // The drift path depends on the size, so it starts again for the new size.
        restartDrifting()
    }

    private func setUpBase() {
        if let baseLayer = layer as? CAGradientLayer {
            baseLayer.colors = [Palette.baseTop.cgColor, Palette.baseBottom.cgColor]
        }
    }

    private func setUpGlows() {
        for glow in Self.glows {
            let centerColor = glow.color.withAlphaComponent(Self.glowCenterOpacity)
            let edgeColor = glow.color.withAlphaComponent(0)

            let glowLayer = CAGradientLayer()
            glowLayer.type = .radial
            // A radial gradient goes from its center (0.5, 0.5) out to its edge (1, 1).
            glowLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            glowLayer.endPoint = CGPoint(x: 1, y: 1)
            glowLayer.colors = [centerColor.cgColor, edgeColor.cgColor]

            layer.addSublayer(glowLayer)
            glowLayers.append(glowLayer)
        }
    }

    private func placeGlows() {
        let glowWidth = bounds.width * Self.glowWidthToViewWidth
        let glowBounds = CGRect(x: 0, y: 0, width: glowWidth, height: glowWidth)

        // Without this, Core Animation would slide the glows to their new place.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (glowLayer, glow) in zip(glowLayers, Self.glows) {
            glowLayer.bounds = glowBounds
            glowLayer.position = point(at: glow.start)
        }
        CATransaction.commit()
    }

    private func restartDrifting() {
        for glowLayer in glowLayers {
            glowLayer.removeAllAnimations()
        }

        let shouldDrift = isDrifting && !UIAccessibility.isReduceMotionEnabled
        guard shouldDrift else {
            return
        }

        for (glowLayer, glow) in zip(glowLayers, Self.glows) {
            glowLayer.add(driftAnimation(for: glow), forKey: "drift")
        }
    }

    /// Moves a glow from its start to its end and back, forever, easing at both ends.
    private func driftAnimation(for glow: Glow) -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "position")
        animation.fromValue = point(at: glow.start)
        animation.toValue = point(at: glow.end)
        animation.duration = glow.driftDuration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // Otherwise the drift stops for good when the app goes to the background.
        animation.isRemovedOnCompletion = false
        return animation
    }

    /// A point inside the view, given as fractions of its width and height.
    private func point(at fraction: CGPoint) -> CGPoint {
        let x = bounds.width * fraction.x
        let y = bounds.height * fraction.y
        return CGPoint(x: x, y: y)
    }
}
