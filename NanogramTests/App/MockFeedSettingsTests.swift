import Testing
@testable import Nanogram

struct MockFeedSettingsTests {
    @Test func defaultsWithoutMockArguments() {
        let settings = MockFeedSettings(arguments: ["Nanogram", "-useMockFeed"])

        #expect(settings.delay == MockFeedSettings.defaultDelay)
        #expect(settings.totalPages == nil)
        #expect(!settings.failsInitialLoad)
    }

    @Test func parsesMockArguments() {
        let settings = MockFeedSettings(arguments: [
            "Nanogram", "-useMockFeed", "-mockDelayMs", "0", "-mockTotalPages", "3", "-mockFailInitialLoad",
        ])

        #expect(settings.delay == .zero)
        #expect(settings.totalPages == 3)
        #expect(settings.failsInitialLoad)
    }

    @Test func laterArgumentsOverrideEarlierOnes() {
        let settings = MockFeedSettings(arguments: ["-mockDelayMs", "200", "-mockDelayMs", "5000"])

        #expect(settings.delay == .milliseconds(5000))
    }

    @Test func ignoresMissingOrInvalidValues() {
        let settings = MockFeedSettings(arguments: ["-mockTotalPages", "lots", "-mockDelayMs"])

        #expect(settings.totalPages == nil)
        #expect(settings.delay == MockFeedSettings.defaultDelay)
    }
}
