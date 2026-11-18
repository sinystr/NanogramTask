import UIKit

/// The bar at the bottom of a game view while the user is browsing: the game's title, who made
/// it, how often it was played, and a like button with the number of likes.
///
/// It sits on a dark fade, so the white text stays readable on top of any game.
final class GameInfoBarView: UIView, GameInfoBarViewProtocol {
    private enum Style {
        static let sidePadding: CGFloat = 16
        static let bottomPadding: CGFloat = 20
        /// Empty space above the text, where the dark fade starts.
        static let fadeHeight: CGFloat = 96
        static let spacingBetweenTexts: CGFloat = 2
        static let spacingAboveChip: CGFloat = 10
        static let spacingBetweenColumns: CGFloat = 16
        static let spacingUnderLikeButton: CGFloat = 4
        static let likeButtonSize: CGFloat = 54
        static let likeIconSize: CGFloat = 24
        static let chipIconSize: CGFloat = 11
        static let chipHeight: CGFloat = 28
        static let chipSidePadding: CGFloat = 10
        static let chipIconSpacing: CGFloat = 5
        static let fadeColor = UIColor.black.withAlphaComponent(0.8)
        static let secondaryTextColor = UIColor.white.withAlphaComponent(0.85)
        static let likedColor = UIColor.systemPink
        /// How much the heart grows before springing back, when the user likes a game.
        static let likePopScale: CGFloat = 1.3
    }

    /// Makes the view draw a fade from clear to dark instead of a single background color.
    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    var onLikeTapped: (() -> Void)?

    private let titleLabel = UILabel()
    private let creatorLabel = UILabel()
    private let playsChip = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let playsLabel = UILabel()
    private let likeButton = UIButton(configuration: .plain())
    private let likesLabel = UILabel()
    private let haptics = UIImpactFeedbackGenerator(style: .light)

    /// The like state on screen, so a new like can be animated.
    private var isLiked = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityIdentifier = "game.infoBar"
        translatesAutoresizingMaskIntoConstraints = false
        setUpFade()
        setUpTexts()
        setUpPlaysChip()
        setUpLikeButton()
        setUpLayout()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Showing content

    func show(_ content: GameInfoBarContent) {
        titleLabel.text = content.title

        creatorLabel.text = content.creator
        creatorLabel.isHidden = content.creator == nil

        playsLabel.text = content.plays
        playsChip.isHidden = content.plays == nil

        likesLabel.text = content.likes
        likesLabel.isHidden = content.likes == nil

        let becameLiked = content.isLiked && !isLiked
        isLiked = content.isLiked
        showLikeButton(isLiked: content.isLiked)

        if becameLiked {
            popLikeButton()
        }
    }

    private func showLikeButton(isLiked: Bool) {
        guard var configuration = likeButton.configuration else {
            return
        }

        if isLiked {
            configuration.image = UIImage(systemName: "heart.fill")
            configuration.baseForegroundColor = Style.likedColor
            likeButton.accessibilityLabel = String(localized: "Unlike")
        } else {
            configuration.image = UIImage(systemName: "heart")
            configuration.baseForegroundColor = .white
            likeButton.accessibilityLabel = String(localized: "Like")
        }

        likeButton.configuration = configuration
    }

    /// Makes the heart grow and spring back, so a new like feels alive.
    private func popLikeButton() {
        likeButton.transform = CGAffineTransform(scaleX: Style.likePopScale, y: Style.likePopScale)
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.45,
            initialSpringVelocity: 0
        ) {
            self.likeButton.transform = .identity
        }
    }

    private func likeButtonTapped() {
        haptics.impactOccurred()
        onLikeTapped?()
    }

    // MARK: - Setup

    private func setUpFade() {
        if let gradientLayer = layer as? CAGradientLayer {
            gradientLayer.colors = [UIColor.clear.cgColor, Style.fadeColor.cgColor]
            gradientLayer.locations = [0, 0.7]
        }
    }

    private func setUpTexts() {
        titleLabel.font = Self.roundedFont(.title2, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2

        creatorLabel.font = Self.roundedFont(.subheadline, weight: .semibold)
        creatorLabel.textColor = Style.secondaryTextColor

        likesLabel.font = Self.roundedFont(.caption1, weight: .bold)
        likesLabel.textColor = .white
    }

    /// A small frosted-glass pill with a play icon and the number of plays.
    private func setUpPlaysChip() {
        playsChip.clipsToBounds = true
        playsChip.layer.cornerRadius = Style.chipHeight / 2
        playsChip.layer.cornerCurve = .continuous

        let iconConfiguration = UIImage.SymbolConfiguration(pointSize: Style.chipIconSize, weight: .bold)
        let icon = UIImageView(image: UIImage(systemName: "play.fill", withConfiguration: iconConfiguration))
        icon.tintColor = .white

        playsLabel.font = Self.roundedFont(.caption1, weight: .semibold)
        playsLabel.textColor = .white

        let row = UIStackView(arrangedSubviews: [icon, playsLabel])
        row.spacing = Style.chipIconSpacing
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        playsChip.contentView.addSubview(row)

        NSLayoutConstraint.activate([
            playsChip.heightAnchor.constraint(equalToConstant: Style.chipHeight),
            row.leadingAnchor.constraint(equalTo: playsChip.contentView.leadingAnchor, constant: Style.chipSidePadding),
            row.trailingAnchor.constraint(equalTo: playsChip.contentView.trailingAnchor, constant: -Style.chipSidePadding),
            row.centerYAnchor.constraint(equalTo: playsChip.contentView.centerYAnchor),
        ])
    }

    /// A round frosted-glass button with a heart.
    private func setUpLikeButton() {
        var configuration = UIButton.Configuration.plain()
        configuration.background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        configuration.background.cornerRadius = Style.likeButtonSize / 2
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            pointSize: Style.likeIconSize,
            weight: .semibold
        )
        likeButton.configuration = configuration
        likeButton.accessibilityIdentifier = "game.like"
        likeButton.addAction(UIAction { [weak self] _ in self?.likeButtonTapped() }, for: .primaryActionTriggered)
        showLikeButton(isLiked: false)
    }

    /// Texts and the plays chip on the left, the like button with its count on the right,
    /// all resting on the bottom of the screen.
    private func setUpLayout() {
        let texts = UIStackView(arrangedSubviews: [titleLabel, creatorLabel])
        texts.axis = .vertical
        texts.spacing = Style.spacingBetweenTexts

        let leftColumn = UIStackView(arrangedSubviews: [texts, playsChip])
        leftColumn.axis = .vertical
        leftColumn.alignment = .leading
        leftColumn.spacing = Style.spacingAboveChip

        let likeColumn = UIStackView(arrangedSubviews: [likeButton, likesLabel])
        likeColumn.axis = .vertical
        likeColumn.alignment = .center
        likeColumn.spacing = Style.spacingUnderLikeButton

        let row = UIStackView(arrangedSubviews: [leftColumn, likeColumn])
        row.alignment = .bottom
        row.spacing = Style.spacingBetweenColumns
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: Style.fadeHeight),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Style.sidePadding),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Style.sidePadding),
            row.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -Style.bottomPadding),
            likeButton.widthAnchor.constraint(equalToConstant: Style.likeButtonSize),
            likeButton.heightAnchor.constraint(equalToConstant: Style.likeButtonSize),
            // The like column is exactly as wide as the button, so it sits on the right edge.
            likeColumn.widthAnchor.constraint(equalTo: likeButton.widthAnchor),
        ])

        // The text column takes all the remaining width; long titles wrap inside it.
        leftColumn.setContentHuggingPriority(.defaultLow, for: .horizontal)
        leftColumn.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    /// The system font in its rounded design, which gives the bar a softer, modern look.
    private static func roundedFont(_ style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let size = UIFont.preferredFont(forTextStyle: style).pointSize
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        guard let roundedDescriptor = font.fontDescriptor.withDesign(.rounded) else {
            return font
        }

        return UIFont(descriptor: roundedDescriptor, size: size)
    }
}
