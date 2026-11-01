import Darwin
import Testing
@testable import FocusWellCore

@Suite struct StolenFocusTests {
    // Terminal (pid 1) is under the mouse and active, Xcode (pid 2) becomes active.
    @Test func appActivatingWhileTypingStealsTheFocus() {
        #expect(StolenFocus.isStolen(activated: 2, previous: 1, mouseWindowOwner: 1,
            sinceClick: 30, sinceShortcut: 30))
    }

    @Test func commandTabOrAClickChoosesTheApp() {
        #expect(!StolenFocus.isStolen(activated: 2, previous: 1, mouseWindowOwner: 1,
            sinceClick: 30, sinceShortcut: 0.2))
        #expect(!StolenFocus.isStolen(activated: 2, previous: 1, mouseWindowOwner: 1,
            sinceClick: 0.2, sinceShortcut: 30))
    }

    // The previous app was not the one under the mouse, so the focus was not FocusWell's.
    @Test func focusAwayFromTheMouseIsLeftAlone() {
        #expect(!StolenFocus.isStolen(activated: 2, previous: 1, mouseWindowOwner: 3,
            sinceClick: 30, sinceShortcut: 30))
        #expect(!StolenFocus.isStolen(activated: 2, previous: 1, mouseWindowOwner: nil,
            sinceClick: 30, sinceShortcut: 30))
        #expect(!StolenFocus.isStolen(activated: 2, previous: nil, mouseWindowOwner: 1,
            sinceClick: 30, sinceShortcut: 30))
    }

    // FocusWell itself activates the app under the mouse
    @Test func theAppUnderTheMouseIsNotStealing() {
        #expect(!StolenFocus.isStolen(activated: 1, previous: 1, mouseWindowOwner: 1,
            sinceClick: 30, sinceShortcut: 30))
    }
}
