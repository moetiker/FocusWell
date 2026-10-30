import AppKit

/// The accessibility API reports positions from the top left of the main screen with
/// y growing downward, NSScreen frames start at their own bottom left with y growing
/// upward. Everything here works in accessibility coordinates.
@MainActor
enum Screens {
    // Tiling window managers park windows of inactive workspaces almost fully
    // offscreen, leaving only the few pixels macOS insists on. Raising such a sliver
    // switches workspace and parks the previous window in its place, which without
    // this check makes the two raise each other indefinitely.
    static let minVisible: CGFloat = 4

    /// The top left corner of a screen.
    static func origin(of screen: NSScreen) -> CGPoint {
        let mainTop = NSScreen.screens.first?.frame.maxY ?? 0
        return CGPoint(x: screen.frame.minX, y: mainTop - screen.frame.maxY)
    }

    static func bounds(of screen: NSScreen) -> CGRect {
        CGRect(origin: origin(of: screen), size: screen.frame.size)
    }

    static func menuBarHeight(of screen: NSScreen) -> CGFloat {
        max(0, screen.frame.maxY - screen.visibleFrame.maxY - 1)
    }

    /// The top left corner of the area all screens together span.
    static func desktopOrigin() -> CGPoint {
        var desktop = CGPoint.zero
        for screen in NSScreen.screens {
            let origin = origin(of: screen)
            desktop.x = min(desktop.x, origin.x)
            desktop.y = min(desktop.y, origin.y)
        }
        return desktop
    }

    static func screen(at point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { bounds(of: $0).contains(point) }
    }

    // Take the centre rather than the top left corner: a window straddling two screens
    // belongs to the one it is mostly on, not the one its corner happens to land in.
    static func screen(of window: AXUIElement) -> NSScreen? {
        guard let frame = window.frame else { return nil }
        return screen(at: CGPoint(x: frame.midX, y: frame.midY))
    }

    static func isOffscreen(_ window: AXUIElement, mouse point: CGPoint) -> Bool {
        guard let screen = screen(at: point), let frame = window.frame else { return false }
        let visible = bounds(of: screen).intersection(frame)
        let offscreen = visible.width < minVisible || visible.height < minVisible
        if offscreen { Log.debug("Offscreen window") }
        return offscreen
    }

    static func isFullScreen(_ window: AXUIElement) -> Bool {
        guard let position = window.position, let screen = screen(at: position),
            let size = window.size else { return false }
        let menuBarHeight = menuBarHeight(of: screen)
        let origin = origin(of: screen)
        let fullScreen = position.x == origin.x &&
            position.y == origin.y + menuBarHeight &&
            size.width == screen.frame.width &&
            size.height == screen.frame.height - menuBarHeight
        if fullScreen { Log.debug("Full screen window") }
        return fullScreen
    }
}
