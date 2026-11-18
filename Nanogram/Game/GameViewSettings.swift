/// Settings for game views. The values are chosen once, in `AppDependencies`.
struct GameViewSettings {
    static let defaultLoadTimeout: Duration = .seconds(15)

    /// A game that is not ready after this much time is shown as failed, with a Retry button.
    let loadTimeout: Duration
    let lifecyclePolicy: any GameLifecyclePolicyProtocol

    init(
        loadTimeout: Duration = GameViewSettings.defaultLoadTimeout,
        lifecyclePolicy: any GameLifecyclePolicyProtocol = GameLifecyclePolicy()
    ) {
        self.loadTimeout = loadTimeout
        self.lifecyclePolicy = lifecyclePolicy
    }
}
