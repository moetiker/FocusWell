import ApplicationServices
import Darwin

/// Undocumented and deprecated system calls. Everything that may break across macOS
/// versions lives here. Each one is looked up at run time: Swift refuses the deprecated
/// Process Manager calls, and the private ones are declared in no header. A call a macOS
/// version lacks is nil, and `isAvailable` is false then.
enum PrivateAPI {
    private typealias GetWindow = @convention(c)
        (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias GetProcessForPID = @convention(c)
        (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias PostEventRecordTo = @convention(c)
        (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
    private typealias SetFrontProcessWithOptions = @convention(c)
        (UnsafeMutablePointer<ProcessSerialNumber>, UInt32, UInt32) -> CGError

    // the first two come with ApplicationServices, which the process has loaded already
    private static let getWindow = symbol("_AXUIElementGetWindow", as: GetWindow.self)
    // the only way to get a ProcessSerialNumber, which the SkyLight calls need
    private static let getProcessForPID = symbol("GetProcessForPID", as: GetProcessForPID.self)

    // Focusing without raising relies on the private SkyLight framework.
    private static let skyLight = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
    private static let postEventRecordTo = symbol(
        "SLPSPostEventRecordTo", in: skyLight, as: PostEventRecordTo.self)
    private static let setFrontProcessWithOptions = symbol(
        "_SLPSSetFrontProcessWithOptions", in: skyLight, as: SetFrontProcessWithOptions.self)

    static var isAvailable: Bool {
        getWindow != nil && getProcessForPID != nil &&
            postEventRecordTo != nil && setFrontProcessWithOptions != nil
    }

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        return getWindow?(element, &id) == .success ? id : nil
    }

    static func process(for pid: pid_t) -> ProcessSerialNumber? {
        var psn = ProcessSerialNumber()
        return getProcessForPID?(pid, &psn) == noErr ? psn : nil
    }

    static func postEventRecord(to psn: inout ProcessSerialNumber, _ bytes: inout [UInt8]) {
        _ = postEventRecordTo?(&psn, &bytes)
    }

    static func setFrontProcess(_ psn: inout ProcessSerialNumber, windowID: CGWindowID, mode: UInt32) {
        _ = setFrontProcessWithOptions?(&psn, windowID, mode)
    }

    /// Looks `name` up in the framework at `path`, or in everything loaded without one.
    private static func symbol<T>(_ name: String, in path: String? = nil, as type: T.Type) -> T? {
        // RTLD_DEFAULT, a C macro Swift does not import
        let everything = UnsafeMutableRawPointer(bitPattern: -2)
        guard let handle = path.map({ dlopen($0, RTLD_LAZY) }) ?? everything,
            let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }
}
