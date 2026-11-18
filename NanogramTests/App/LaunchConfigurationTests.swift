import Testing
@testable import Nanogram

struct LaunchConfigurationTests {
    @Test func withoutArgumentsUsesTheRealFeedAndPreloads() {
        let configuration = LaunchConfiguration(arguments: ["Nanogram"])

        #expect(configuration.mockFeed == nil)
        #expect(configuration.preloadsAdjacentGames)
    }

    @Test func useMockFeedTurnsOnTheMockFeed() {
        let configuration = LaunchConfiguration(arguments: ["Nanogram", "-useMockFeed", "-mockTotalPages", "3"])

        #expect(configuration.mockFeed?.totalPages == 3)
    }

    @Test func mockArgumentsWithoutUseMockFeedAreIgnored() {
        let configuration = LaunchConfiguration(arguments: ["Nanogram", "-mockDelayMs", "0", "-mockTotalPages", "3"])

        #expect(configuration.mockFeed == nil)
    }

    @Test func disableGamePreloadTurnsOffPreloading() {
        let configuration = LaunchConfiguration(arguments: ["Nanogram", "-disableGamePreload"])

        #expect(!configuration.preloadsAdjacentGames)
    }
}
