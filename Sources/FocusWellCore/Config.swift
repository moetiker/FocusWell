import CoreGraphics

/// How the focus follows the mouse. The app runs with the defaults, the fields
/// exist so they can be tuned without touching the engine.
public struct Settings: Sendable {
    /// How often the mouse position is checked.
    public var pollMillis = 50
    /// Ticks the mouse has to rest on a window before it gets the focus. 1 focuses at once.
    public var focusDelayCount = 1
    public var verbose = false
    /// Movements up to this distance do not count.
    public var mouseDelta: Double = 0
    /// Change the focus only once the mouse stops moving.
    public var requireMouseStop = true
    public var requireMultipleScreens = false
    /// Change the focus only when the mouse is on another screen than the focused window.
    public var requireScreenChange = false
    public var ignoreSpaceChanged = false
    /// Apps by name that never get the focus. FocusWell adds AssistiveControl itself.
    public var ignoreApps: [String] = []
    /// Turns ignoreApps into the list of the only apps that get the focus.
    public var invertIgnoreApps = false
    /// Regular expressions for window titles that never get the focus.
    public var ignoreTitles: [String] = []
    /// While one of these apps is in front, the focus stays where it is.
    public var stayFocusedBundleIds: [String] = []
    /// Holding this key pauses FocusWell.
    public var disableKey: DisableKey = .control
    public var invertDisableKey = false

    public enum DisableKey: String, Sendable {
        case control, option, disabled

        var flags: CGEventFlags? {
            switch self {
            case .control: .maskControl
            case .option: .maskAlternate
            case .disabled: nil
            }
        }
    }

    public init() {}
}
