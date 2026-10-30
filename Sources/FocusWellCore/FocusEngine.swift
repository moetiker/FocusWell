import AppKit
import ApplicationServices
import PrivateAPI

/// Gives the window under the mouse the focus without raising it. Everything runs on
/// the main run loop: the poll timer, the space notification and the accessibility
/// observer.
@MainActor
public final class FocusEngine {
    // macOS Monterey introduced a transparent 3 pixel border around each window. When
    // two windows are visually connected and not overlapping, in reality they are, and
    // the mouse has to move 3 pixels further to reach the other one. The same border
    // makes windows connected to the menu bar take the focus. The mouse position is
    // corrected before looking up the window under it.
    static let windowCorrection: CGFloat = 3
    static let menuBarCorrection: CGFloat = 8
    // Within windowCorrection pixels of a screen edge, the mouse counts as being
    // screenEdgeCorrection pixels away from that edge.
    static let screenEdgeCorrection: CGFloat = 1 // 1 <= value <= windowCorrection

    static var shared: FocusEngine?

    let settings: Settings
    let ignoreApps: [String]
    let systemWide = AXUIElementCreateSystemWide()
    var dockApp: AXUIElement?
    var reportedAPIDisabled = false

    private var oldPoint = CGPoint.zero
    private var oldCorrectedPoint = CGPoint.zero
    private var loggedDisplay = kCGNullDirectDisplay
    private var propagateMouseMoved = false
    private var spaceHasChanged = false
    // after a space change the window under the mouse gets the focus a few times,
    // because the space switch itself focuses another window
    private var focusTimes = 0
    // delayTicks = 0 -> delay disabled
    // delayTicks = 1 -> delay finished
    // delayTicks = n -> delay started
    private var delayTicks = 0

    private var axObserver: AXObserver?
    private var previousMouseWindowID: CGWindowID?
    fileprivate var lastDestroyedMouseWindowID: CGWindowID?

    private var observers: [NSObjectProtocol] = []
    private var pollTimer: Timer?

    public init(settings: Settings) {
        self.settings = settings
        ignoreApps = settings.ignoreApps + [Rules.assistiveControl]
        Log.verbose = settings.verbose
    }

    /// Whether focusing without raising is possible: it needs the private SkyLight api.
    public static var isAvailable: Bool { FocusFirst.isAvailable }

    /// Whether this process may use the accessibility api. With `prompt`, macOS asks
    /// the user to grant it when it has not been granted yet.
    public static func isTrusted(prompt: Bool = false) -> Bool {
        // The value of kAXTrustedCheckOptionPrompt, a C global that Swift 6 refuses to read
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    public func start() {
        Self.shared?.stop()
        Self.shared = self

        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                Log.debug("Space changed")
                FocusEngine.shared?.spaceChanged()
            }
        })

        // The timer only fires in the default run loop mode, so the focus does not
        // change while a menu is open.
        let timer = Timer(timeInterval: Double(settings.pollMillis) / 1000, repeats: true) { _ in
            MainActor.assumeIsolated { FocusEngine.shared?.onTick() }
        }
        RunLoop.main.add(timer, forMode: .default)
        pollTimer = timer

        findDockApplication()
    }

    /// Undoes everything start did, so that a new instance with other settings can
    /// take over in the same process.
    public func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers = []
        if let axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(axObserver), .commonModes)
        }
        axObserver = nil
        if Self.shared === self { Self.shared = nil }
    }

    private func spaceChanged() {
        spaceHasChanged = true
        oldPoint = .zero
    }

    private func onTick() {
        // determine if the mouse moved
        var mousePoint = CGEvent(source: nil)?.location ?? .zero
        let mouseXDiff = mousePoint.x - oldPoint.x
        let mouseYDiff = mousePoint.y - oldPoint.y
        oldPoint = mousePoint

        var mouseMoved = abs(mouseXDiff) > settings.mouseDelta || abs(mouseYDiff) > settings.mouseDelta
        let mouseStopped = !mouseMoved
        mouseMoved = mouseMoved || propagateMouseMoved
        propagateMouseMoved = false

        if delayTicks > 1 { delayTicks -= 1 }

        // the correction is applied before any of the returns below, so that
        // oldCorrectedPoint always has a recent value
        if mouseMoved {
            mousePoint = correctedMousePoint(mousePoint, dx: mouseXDiff, dy: mouseYDiff)
            oldCorrectedPoint = mousePoint
        } else {
            mousePoint = oldCorrectedPoint
        }

        if spaceHasChanged {
            // a space change has priority over waiting for the delay
            if mouseMoved { return }
            if !settings.ignoreSpaceChanged {
                focusTimes = 3
                delayTicks = 0
            }
            spaceHasChanged = false
        } else if settings.requireMouseStop && !mouseStopped && mouseMoved {
            delayTicks = 0
            // propagate the movement to restart the delay once the mouse stops
            propagateMouseMoved = true
            return
        }

        // mouseMoved: decide whether the window under the mouse needs the focus
        // delayTicks: count down as long as the mouse doesn't move
        // focusTimes: the window needs the focus a couple of times
        guard mouseMoved || delayTicks != 0 || focusTimes != 0 else { return }

        // nothing changes while something is dragged (resizing a window for instance)
        var abort = CGEventSource.buttonState(.combinedSessionState, button: .left) ||
            CGEventSource.buttonState(.combinedSessionState, button: .right) ||
            dockActive() || missionControlActive() ||
            (settings.requireMultipleScreens && NSScreen.screens.count < 2)

        if !abort, let disableKey = settings.disableKey.flags {
            let flags = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)?.flags ?? []
            abort = flags.contains(disableKey) != settings.invertDisableKey
        }

        let frontmostApp = NSWorkspace.shared.frontmostApplication
        if let bundleId = frontmostApp?.bundleIdentifier {
            abort = abort || settings.stayFocusedBundleIds.contains(bundleId)
        }

        if abort {
            Log.debug("Abort focus")
            focusTimes = 0
            delayTicks = 0
            return
        }

        guard let mouseWindow = mouseWindow(at: mousePoint), let mouseWindowPID = mouseWindow.pid else {
            return
        }
        let mouseWindowID = mouseWindow.windowID
        let mouseWindowPresent = mouseWindowID == nil || mouseWindowID != lastDestroyedMouseWindowID
        if mouseWindowPresent {
            if mouseWindowID != previousMouseWindowID {
                previousMouseWindowID = mouseWindowID
                lastDestroyedMouseWindowID = nil
                focusTimes = 0
                delayTicks = 0
                observeDestruction(of: mouseWindow, id: mouseWindowID, pid: mouseWindowPID)
            }
        } else {
            Log.debug("Mouse window not present")
        }

        var appRaisesOnFocus = false
        var needsFocus = !settings.invertIgnoreApps && mouseWindowPresent
        let mouseWindowApp = AXUIElementCreateApplication(mouseWindowPID)
        if needsFocus && mouseWindow.titleEquals([Rules.noTitle, Rules.untitled]) {
            needsFocus = isMainWindow(mouseWindowApp, mouseWindow, chromeApp: isPWA(
                NSRunningApplication(processIdentifier: mouseWindowPID)?.bundleIdentifier))
            if !needsFocus { Log.debug("Excluding window") }
        } else if needsFocus && mouseWindow.titleEquals(
            [Rules.bartenderBar, Rules.zim, Rules.appStoreSearchResults], patterns: settings.ignoreTitles) {
            needsFocus = false
            Log.debug("Excluding window")
        } else if mouseWindowPresent {
            if mouseWindowApp.titleEquals(ignoreApps) {
                needsFocus = settings.invertIgnoreApps
                Log.debug(settings.invertIgnoreApps ? "Including app" : "Excluding app")
            }
            appRaisesOnFocus = mouseWindowApp.titleEquals(Rules.appsRaisingOnFocus)
        }
        if needsFocus && Screens.isOffscreen(mouseWindow, mouse: mousePoint) {
            needsFocus = false
            Log.debug("Excluding offscreen window")
        }

        var focusedWindowID: CGWindowID?
        var focusedWindowPSN: ProcessSerialNumber?
        if needsFocus {
            let frontmostPID = frontmostApp?.processIdentifier ?? 0
            let frontmost = AXUIElementCreateApplication(frontmostPID)
            if let focusedWindow = frontmost.element(kAXFocusedWindowAttribute) {
                focusedWindow.logTitle("Focused window")
                focusedWindowID = focusedWindow.windowID
                needsFocus = mouseWindowID != focusedWindowID
                if needsFocus && settings.requireScreenChange &&
                    Screens.screen(of: focusedWindow) == Screens.screen(at: mousePoint) {
                    needsFocus = false
                    Log.debug("Excluding same screen")
                }
                let notContainedWithin = needsFocus && !contained(focusedWindow, within: mouseWindow)
                needsFocus = needsFocus && isMainWindow(frontmost, focusedWindow,
                    chromeApp: isPWA(frontmostApp?.bundleIdentifier)) &&
                    ((mouseWindowPID != frontmostPID && !appRaisesOnFocus) || notContainedWithin)
                var psn = ProcessSerialNumber()
                if needsFocus && AR_GetProcessForPID(frontmostPID, &psn) { focusedWindowPSN = psn }
            } else {
                Log.debug("No focused window")
                if frontmost.element(kAXMainWindowAttribute) != nil { needsFocus = false }
            }
        }

        guard needsFocus else {
            focusTimes = 0
            delayTicks = 0
            return
        }

        if delayTicks == 0 {
            // start the delay
            delayTicks = settings.focusDelayCount
        }
        guard focusTimes != 0 || delayTicks == 1 else { return }
        delayTicks = 0 // disable delay
        if focusTimes != 0 { focusTimes -= 1 } else { focusTimes = 3 }

        var mouseWindowPSN = ProcessSerialNumber()
        guard AR_GetProcessForPID(mouseWindowPID, &mouseWindowPSN) else { return }
        let floatingWindow = [kAXFloatingWindowSubrole, kAXSystemFloatingWindowSubrole,
            kAXUnknownSubrole].contains(mouseWindow.subrole ?? "")
        if floatingWindow {
            // TODO: focusWithoutRaise seems unable to focus floating windows
            Log.debug("Unable to focus floating window")
            return
        }
        FocusFirst.focusWithoutRaise(&mouseWindowPSN, windowID: mouseWindowID ?? 0,
            focused: focusedWindowPSN, focusedWindowID: focusedWindowID ?? 0)
    }

    private func correctedMousePoint(_ point: CGPoint, dx: CGFloat, dy: CGFloat) -> CGPoint {
        let screen = Screens.screen(at: point)
        if settings.verbose {
            // a screen keeps its display id across a reconfiguration, its NSScreen
            // does not necessarily keep its address
            let display = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")]
                as? NSNumber)?.uint32Value ?? kCGNullDirectDisplay
            if display != loggedDisplay {
                loggedDisplay = display
                if let screen {
                    let origin = Screens.origin(of: screen)
                    Log.debug(String(format: "Mouse screen: %@, origin (%.0f, %.0f), mouse (%.1f, %.1f)",
                        screen.localizedName, origin.x, origin.y, point.x, point.y))
                } else {
                    Log.debug(String(format: "Mouse screen: none, mouse (%.1f, %.1f)", point.x, point.y))
                }
            }
        }

        var corrected = point
        corrected.x += dx > 0 ? Self.windowCorrection : -Self.windowCorrection
        corrected.y += dy > 0 ? Self.windowCorrection : -Self.windowCorrection
        guard let screen else { return corrected }

        let bounds = Screens.bounds(of: screen)
        if oldPoint.x > bounds.maxX - Self.windowCorrection {
            Log.debug("Screen edge correction")
            corrected.x = bounds.maxX - Self.screenEdgeCorrection
        } else if oldPoint.x < bounds.minX + Self.windowCorrection - 1 {
            Log.debug("Screen edge correction")
            corrected.x = bounds.minX + Self.screenEdgeCorrection
        }

        if oldPoint.y > bounds.maxY - Self.windowCorrection {
            Log.debug("Screen edge correction")
            corrected.y = bounds.maxY - Self.screenEdgeCorrection
        } else if corrected.y < bounds.minY + Screens.menuBarHeight(of: screen) + Self.menuBarCorrection {
            Log.debug("Menu bar correction")
            corrected.y = bounds.minY
        }
        return corrected
    }

    /// Windows that are closed while the mouse is above them must not get the focus
    /// as a ghost: the accessibility api can still return them for a moment.
    private func observeDestruction(of window: AXUIElement, id: CGWindowID?, pid: pid_t) {
        if let axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetMain(),
                AXObserverGetRunLoopSource(axObserver), .commonModes)
            self.axObserver = nil
        }

        var observer: AXObserver?
        AXObserverCreate(pid, { _, _, notification, refcon in
            MainActor.assumeIsolated {
                if (notification as String) == kAXUIElementDestroyedNotification {
                    FocusEngine.shared?.lastDestroyedMouseWindowID =
                        CGWindowID(truncatingIfNeeded: UInt(bitPattern: refcon))
                }
            }
        }, &observer)
        guard let observer else { return }
        AXObserverAddNotification(observer, window, kAXUIElementDestroyedNotification as CFString,
            UnsafeMutableRawPointer(bitPattern: UInt(id ?? 0)))
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        axObserver = observer
    }
}
