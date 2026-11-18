/// How far the game in one game view has got with loading.
enum GameLoadState: Equatable {
    /// Nothing has been loaded yet.
    case idle
    case loading
    case ready
    case failed(GameLoadError)
}
