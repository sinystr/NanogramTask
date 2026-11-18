import SwiftUI

/// Where the app starts.
@main
struct NanogramApp: App {
    @State private var dependencies = AppDependencies(
        launch: LaunchConfiguration(arguments: ProcessInfo.processInfo.arguments)
    )

    var body: some Scene {
        WindowGroup {
            FeedView(viewModel: dependencies.feedViewModel, gameViewSettings: dependencies.gameViewSettings)
        }
    }
}
