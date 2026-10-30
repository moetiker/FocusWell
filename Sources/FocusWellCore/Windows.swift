import AppKit
import ApplicationServices
import PrivateAPI

extension FocusEngine {
    static let stackThreshold = 20

    /// The window under the mouse, or nil when there is nothing that may get the focus.
    func mouseWindow(at point: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        let error = AXUIElementCopyElementAtPosition(
            systemWide, Float(point.x), Float(point.y), &element)

        var window: AXUIElement?
        if let element {
            window = focusableWindow(element, at: point, depth: 0)
        } else {
            switch error {
            case .cannotComplete, .notImplemented:
                // fallback, happens for apps that do not support the Accessibility API
                Log.debug("Copy element: no accessibility support")
                window = fallback(at: point)
            case .illegalArgument:
                // fallback, happens for Progressive Web Apps (PWAs)
                Log.debug("Copy element: illegal argument")
                window = fallback(at: point)
            case .noValue:
                // fallback, happens sometimes when switching to another app (with cmd-tab)
                Log.debug("Copy element: no value")
                window = fallback(at: point)
            case .attributeUnsupported:
                // no fallback, happens when hovering into volume/WiFi menubar window
                Log.debug("Copy element: attribute unsupported")
            case .failure:
                // no fallback, happens when hovering over the menubar itself
                Log.debug("Copy element: failure")
            case .apiDisabled:
                // Reported even when not verbose: every accessibility call fails from
                // here on, so nothing gets the focus. Rebuilding changes an ad hoc
                // signature, which leaves a stale Accessibility entry behind.
                if !reportedAPIDisabled {
                    reportedAPIDisabled = true
                    Log.always("Accessibility permission is not working. If you rebuilt FocusWell, " +
                        "remove it under System Settings > Privacy & Security > Accessibility " +
                        "and add it again.")
                }
            default:
                Log.debug("Copy element: AXError \(error.rawValue)")
            }
        }

        if let window { window.logTitle("Mouse window") } else { Log.debug("No focusable window") }
        return window
    }

    /// Walks up from the element under the mouse to the window it belongs to.
    private func focusableWindow(_ element: AXUIElement?, at point: CGPoint, depth: Int) -> AXUIElement? {
        guard let element else { return nil }
        if depth >= Self.stackThreshold {
            Log.debug("Stack threshold reached")
            return nil
        }

        if let role = element.role {
            if [kAXDockItemRole, kAXMenuItemRole, kAXMenuRole, kAXMenuBarRole,
                kAXMenuBarItemRole].contains(role) {
                return nil
            }
            if [kAXWindowRole, kAXSheetRole, kAXDrawerRole].contains(role) {
                return element
            }
            // XQuartz manages the focus of its windows itself
            if role == kAXApplicationRole && element.titleEquals([Rules.xQuartz]) {
                return nil
            }
        }

        let parent = element.element(kAXParentAttribute)
        if let window = focusableWindow(parent, at: point, depth: depth + 1) { return window }
        if let window = element.element(kAXWindowAttribute) { return window }
        return parent == nil ? fallback(at: point) : nil
    }

    /// For apps without (proper) accessibility support: find the topmost window under
    /// the mouse in the window server's list and look it up among the app's windows.
    private func fallback(at point: CGPoint) -> AXUIElement? {
        Log.debug("Fallback")
        guard let topWindow = Self.topWindow(at: point) else { return nil }
        let pid = (topWindow[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
        let topWindowID = (topWindow[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
        guard topWindowID != 0,
            let windows = AXUIElementCreateApplication(pid).elements(kAXWindowsAttribute) else { return nil }
        return windows.first { $0.windowID == topWindowID }
    }

    private static func topWindow(at point: CGPoint) -> [String: Any]? {
        let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
        return windows?.first { window in
            guard (window[kCGWindowLayer as String] as? NSNumber) == 0 else { return false }
            let bounds = window[kCGWindowBounds as String] as? [String: NSNumber]
            func value(_ key: String) -> Int { bounds?[key]?.intValue ?? 0 }
            return CGRect(x: value("X"), y: value("Y"), width: value("Width"), height: value("Height"))
                .contains(point)
        }
    }

    func isMainWindow(_ app: AXUIElement, _ window: AXUIElement, chromeApp: Bool) -> Bool {
        var mainWindow = window.isTrue(kAXMainAttribute) ?? false
        if mainWindow, let subrole = window.subrole {
            mainWindow = subrole != kAXDialogSubrole
            if !mainWindow { Log.debug("Dialog window") }
        }

        let finderApp = app.titleEquals([Rules.finder])
        mainWindow = mainWindow && (chromeApp || finderApp ||
            !window.titleEquals([Rules.noTitle]) ||
            app.titleEquals(Rules.mainWindowAppsWithoutTitle))
        mainWindow = mainWindow || (!finderApp && Screens.isFullScreen(window))

        if !mainWindow { Log.debug("Not a main window") }
        return mainWindow
    }

    func isPWA(_ bundleIdentifier: String?) -> Bool {
        let pwa = Rules.isPWA(bundleIdentifier)
        if pwa { Log.debug("PWA: \(bundleIdentifier ?? "")") }
        return pwa
    }

    /// Whether `inner` lies strictly within `outer`.
    func contained(_ inner: AXUIElement, within outer: AXUIElement) -> Bool {
        guard let a = inner.frame, let b = outer.frame else { return false }
        return a.minX > b.minX && a.minY > b.minY && a.maxX < b.maxX && a.maxY < b.maxY
    }

    func findDockApplication() {
        if let dock = NSWorkspace.shared.runningApplications.first(where: {
            $0.bundleIdentifier == Rules.dockBundleId
        }) {
            dockApp = AXUIElementCreateApplication(dock.processIdentifier)
        } else {
            Log.debug("Dock application isn't running")
        }
    }

    func dockActive() -> Bool {
        guard dockApp?.attribute(kAXFocusedUIElementAttribute) != nil else { return false }
        Log.debug("Dock is active")
        return true
    }

    func missionControlActive() -> Bool {
        let active = dockApp?.elements(kAXChildrenAttribute)?.contains {
            $0.role == kAXGroupRole && $0.titleEquals([Rules.missionControl])
        } ?? false
        if active { Log.debug("Mission Control is active") }
        return active
    }
}
