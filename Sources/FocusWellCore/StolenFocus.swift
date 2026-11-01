import Foundation

/// An app that makes itself active, for example one that shows its window seconds after
/// it was started, takes the focus from the window under the mouse while the user types
/// there. FocusWell only acted on mouse movements, so the keystrokes went to the other
/// app until the mouse moved.
enum StolenFocus {
    /// A click or a shortcut this many seconds before an activation counts as its cause.
    static let userInputWindow: TimeInterval = 1
    /// An app chosen in a launcher can take several seconds to start and make itself
    /// active, long after the launcher closed.
    static let launcherWindow: TimeInterval = 10

    /// Whether the app `activated` became active on its own, taking the focus from
    /// `previous`, whose window is under the mouse.
    ///
    /// A click, in the Dock or on a notification for example, or a shortcut with
    /// command, option or control, such as command-tab, is the user choosing the app;
    /// typing without those keys is not. Neither is the return that picks an app in
    /// Spotlight, so a launcher window seen since the last activation also counts.
    static func isStolen(
        activated: pid_t, previous: pid_t?, mouseWindowOwner: pid_t?,
        sinceClick: TimeInterval, sinceShortcut: TimeInterval, sinceLauncher: TimeInterval
    ) -> Bool {
        guard let previous, mouseWindowOwner == previous, activated != previous else { return false }
        return sinceClick > userInputWindow && sinceShortcut > userInputWindow &&
            sinceLauncher > launcherWindow
    }
}
