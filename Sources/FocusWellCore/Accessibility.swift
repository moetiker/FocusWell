import AppKit
import ApplicationServices

@MainActor
enum Log {
    static var verbose = false

    static func debug(_ message: @autoclosure () -> String) {
        if verbose { NSLog("%@", message()) }
    }

    static func always(_ message: String) {
        NSLog("%@", message)
    }
}

extension AXUIElement {
    func attribute(_ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(self, name as CFString, &value)
        return value
    }

    func element(_ name: String) -> AXUIElement? {
        guard let value = attribute(name), CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }

    func elements(_ name: String) -> [AXUIElement]? {
        attribute(name) as? [AXUIElement]
    }

    func string(_ name: String) -> String? {
        attribute(name) as? String
    }

    func isTrue(_ name: String) -> Bool? {
        guard let value = attribute(name), CFGetTypeID(value) == CFBooleanGetTypeID() else {
            return nil
        }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    var title: String? { string(kAXTitleAttribute) }
    var role: String? { string(kAXRoleAttribute) }
    var subrole: String? { string(kAXSubroleAttribute) }

    var pid: pid_t? {
        var pid: pid_t = 0
        return AXUIElementGetPid(self, &pid) == .success ? pid : nil
    }

    var windowID: CGWindowID? { PrivateAPI.windowID(of: self) }

    var position: CGPoint? {
        var point = CGPoint.zero
        guard let value = attribute(kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID(),
            AXValueGetValue((value as! AXValue), .cgPoint, &point) else { return nil }
        return point
    }

    var size: CGSize? {
        var size = CGSize.zero
        guard let value = attribute(kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID(),
            AXValueGetValue((value as! AXValue), .cgSize, &size) else { return nil }
        return size
    }

    /// In accessibility coordinates: from the top left of the main screen, y down.
    var frame: CGRect? {
        guard let size, let position else { return nil }
        return CGRect(origin: position, size: size)
    }

    // TODO: does not take into account different languages
    /// An element without a title matches an empty string in `titles`.
    func titleEquals(_ titles: [String], patterns: [String] = []) -> Bool {
        guard let title else { return titles.contains("") }
        if titles.contains(title) { return true }
        return patterns.contains {
            (title as NSString).range(of: $0, options: .regularExpression).location != NSNotFound
        }
    }

    @MainActor
    func logTitle(_ prefix: String) {
        if let title {
            Log.debug("\(prefix): `\(title)`")
        } else if let pid, let name = NSRunningApplication(processIdentifier: pid)?.localizedName {
            Log.debug("\(prefix) (app name): `\(name)`")
        } else {
            Log.debug("\(prefix): null")
        }
    }
}
