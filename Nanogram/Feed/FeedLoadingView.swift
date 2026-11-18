import SwiftUI

/// The full-screen spinner shown while the first games load.
struct FeedLoadingView: View {
    private enum Layout {
        static let spacingBetweenItems: CGFloat = 16
        static let paddingAroundContent: CGFloat = 32
    }

    var body: some View {
        VStack(spacing: Layout.spacingBetweenItems) {
            ProgressView()
                .controlSize(.large)
            Text("Loading games…")
                .font(.headline)
                .accessibilityIdentifier("feedLoading")
        }
        .padding(Layout.paddingAroundContent)
    }
}

#Preview {
    FeedLoadingView()
        .preferredColorScheme(.dark)
}
