import SwiftUI

/// The full-screen error shown when the first games can't be loaded.
struct FeedErrorView: View {
    private enum Layout {
        static let spacingBetweenSections: CGFloat = 16
        static let spacingBetweenTexts: CGFloat = 8
        static let iconSize: CGFloat = 44
        static let minimumButtonWidth: CGFloat = 120
        static let paddingAroundContent: CGFloat = 32
    }

    let error: FeedError
    let retry: () -> Void

    private var iconName: String {
        error == .offline ? "wifi.slash" : "exclamationmark.triangle"
    }

    var body: some View {
        VStack(spacing: Layout.spacingBetweenSections) {
            Image(systemName: iconName)
                .font(.system(size: Layout.iconSize, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: Layout.spacingBetweenTexts) {
                Text(error.title)
                    .font(.title2.bold())
                Text(error.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("feedError.message")
            }

            Button(action: retry) {
                Text("Retry")
                    .frame(minWidth: Layout.minimumButtonWidth)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("feedError.retry")
        }
        .multilineTextAlignment(.center)
        .padding(Layout.paddingAroundContent)
    }
}

#Preview {
    FeedErrorView(error: .offline, retry: {})
        .preferredColorScheme(.dark)
}
