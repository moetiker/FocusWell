// Moves the mouse between the windows of two apps and checks that FocusWell gives
// the window under the mouse the focus without raising it. Runs inside the test VM,
// see scripts/test-vm; needs Accessibility access for itself.
//
//   focus-check <bundle id A> <bundle id B>
//
// Both apps must be running with one window each. Exit 0 when every check passes.
import AppKit

func fail(_ message: String) -> Never {
    print("FAIL: \(message)")
    exit(1)
}

func app(_ bundleID: String) -> (pid: pid_t, element: AXUIElement) {
    guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?
        .processIdentifier else { fail("\(bundleID) is not running") }
    return (pid, AXUIElementCreateApplication(pid))
}

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func firstWindow(_ app: AXUIElement, _ name: String) -> AXUIElement {
    guard let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement], let window = windows.first
    else { fail("\(name) has no window") }
    return window
}

func move(_ window: AXUIElement, to point: CGPoint) {
    var p = point
    let value = AXValueCreate(.cgPoint, &p)!
    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
}

func frame(_ window: AXUIElement) -> CGRect {
    var origin = CGPoint.zero, size = CGSize.zero
    if let v = attribute(window, kAXPositionAttribute) { AXValueGetValue(v as! AXValue, .cgPoint, &origin) }
    if let v = attribute(window, kAXSizeAttribute) { AXValueGetValue(v as! AXValue, .cgSize, &size) }
    return CGRect(origin: origin, size: size)
}

/// The process macOS considers frontmost. The system-wide AX element answered
/// kAXErrorCannotComplete (-25204) in the test VM, so ask lsappinfo, as desktest does.
func focusedPID() -> pid_t? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/sh")
    task.arguments = ["-c", "lsappinfo info -only pid \"$(lsappinfo front)\""]
    let pipe = Pipe()
    task.standardOutput = pipe
    guard (try? task.run()) != nil else { return nil }
    task.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    // The output holds "pid = 1119" among other fields
    guard let r = out.range(of: #"pid = [0-9]+"#, options: .regularExpression) else { return nil }
    return pid_t(out[r].dropFirst(6))
}

/// Front-to-back order of the normal windows of the two processes.
func windowOrder(_ pids: [pid_t]) -> [pid_t] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        as? [[String: Any]] ?? []
    var order: [pid_t] = []
    for info in list {
        guard (info[kCGWindowLayer as String] as? Int) == 0,
              let pid = info[kCGWindowOwnerPID as String] as? pid_t,
              pids.contains(pid), !order.contains(pid) else { continue }
        order.append(pid)
    }
    return order
}

func pointer(to point: CGPoint) {
    // Two steps, so FocusWell's 50 ms poll sees a movement and then a stop
    let start = CGPoint(x: point.x - 30, y: point.y)
    for p in [start, point] {
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?
            .post(tap: .cghidEventTap)
        usleep(200_000)
    }
    sleep(2)
}

func center(_ r: CGRect) -> CGPoint { CGPoint(x: r.midX, y: r.midY) }

let args = CommandLine.arguments
guard args.count == 3 else { fail("usage: focus-check <bundle id A> <bundle id B>") }
guard AXIsProcessTrusted() else { fail("focus-check has no Accessibility access") }

let a = app(args[1]), b = app(args[2])
let windowA = firstWindow(a.element, args[1]), windowB = firstWindow(b.element, args[2])

// Side by side, so the mouse can reach either window without covering the other
let screen = CGDisplayBounds(CGMainDisplayID())
// On the VM's 1024 px screen TextEdit's window alone was 673 px wide and overlapped
// Calculator, so A gets narrower (if it can) and B goes to the right edge.
var sizeA = CGSize(width: screen.width / 2 - 40, height: 400)
AXUIElementSetAttributeValue(windowA, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &sizeA)!)
move(windowA, to: CGPoint(x: screen.minX + 20, y: screen.minY + 80))
move(windowB, to: CGPoint(x: screen.maxX - frame(windowB).width - 20, y: screen.minY + 80))
usleep(500_000)
let frameA = frame(windowA), frameB = frame(windowB)
guard !frameA.intersects(frameB) else { fail("windows overlap: \(frameA) \(frameB)") }

AXUIElementSetAttributeValue(a.element, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
pointer(to: center(frameA))
guard focusedPID() == a.pid else { fail("\(args[1]) (pid \(a.pid)) did not get the focus to start with, front pid \(focusedPID() ?? -1)") }
guard windowOrder([a.pid, b.pid]) == [a.pid, b.pid] else { fail("\(args[1]) is not in front to start with") }
print("ok: \(args[1]) focused and in front")

pointer(to: center(frameB))
guard focusedPID() == b.pid else { fail("mouse over \(args[2]), but it did not get the focus") }
print("ok: mouse over \(args[2]) gave it the focus")
guard windowOrder([a.pid, b.pid]) == [a.pid, b.pid] else { fail("\(args[2]) was raised above \(args[1])") }
print("ok: \(args[2]) was not raised")

pointer(to: center(frameA))
guard focusedPID() == a.pid else { fail("mouse back over \(args[1]), but it did not get the focus") }
print("ok: mouse back over \(args[1]) gave it the focus")
print("PASS")
