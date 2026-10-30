import Testing
@testable import FocusWellCore

@Suite struct RulesTests {
    @Test(arguments: [
        ("com.google.Chrome.app.abcdefgh", true),
        ("com.google.Chrome.canary.app.abcdefgh", true),
        ("com.brave.Browser.app.abcdefgh", false),
        ("com.microsoft.edgemac.app.abcdefgh", true),
        ("com.pake.myapp", true),
        ("com.apple.Safari", false),
    ])
    func pwa(bundleId: String, expected: Bool) {
        #expect(Rules.isPWA(bundleId) == expected)
    }

    @Test func noBundleIdIsNoPWA() {
        #expect(!Rules.isPWA(nil))
    }

    @Test func defaultsFocusAtOnceAndPauseWithControl() {
        let settings = Settings()
        #expect(settings.focusDelayCount == 1)
        #expect(settings.pollMillis == 50)
        #expect(settings.requireMouseStop)
        #expect(settings.disableKey == .control)
    }
}
