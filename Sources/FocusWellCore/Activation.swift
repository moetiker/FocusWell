import AppKit
import ApplicationServices

/// Focusing a window without raising it relies on the private SkyLight api. It can
/// break easily across macOS versions, there is no guarantee it keeps on working.
///
/// The two methods below were copied from https://github.com/koekeishiya/yabai and
/// slightly modified. See also:
/// https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
@MainActor
enum FocusFirst {
    static let userGenerated: UInt32 = 0x200

    static var isAvailable: Bool { PrivateAPI.isAvailable }

    static func makeKeyWindow(_ psn: inout ProcessSerialNumber, windowID: CGWindowID) {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x3a] = 0x10
        put(windowID, into: &bytes, at: 0x3c)
        bytes.replaceSubrange(0x20..<0x30, with: repeatElement(0xff, count: 0x10))

        bytes[0x08] = 0x01
        PrivateAPI.postEventRecord(to: &psn, &bytes)
        bytes[0x08] = 0x02
        PrivateAPI.postEventRecord(to: &psn, &bytes)
    }

    static func focusWithoutRaise(
        _ psn: inout ProcessSerialNumber, windowID: CGWindowID,
        focused focusedPSN: ProcessSerialNumber?, focusedWindowID: CGWindowID
    ) {
        Log.debug("Focus")
        if var focusedPSN, isSameProcess(psn, focusedPSN) {
            Log.debug("Same process")
            var bytes = [UInt8](repeating: 0, count: 0xf8)
            bytes[0x04] = 0xf8
            bytes[0x08] = 0x0d

            bytes[0x8a] = 0x02
            put(focusedWindowID, into: &bytes, at: 0x3c)
            PrivateAPI.postEventRecord(to: &focusedPSN, &bytes)

            // @hack
            // Artificially delay the activation by 10ms. This is necessary
            // because some applications appear to be confused if both of
            // the events appear instantaneously.
            usleep(10000)

            bytes[0x8a] = 0x01
            put(windowID, into: &bytes, at: 0x3c)
            PrivateAPI.postEventRecord(to: &psn, &bytes)
        }

        PrivateAPI.setFrontProcess(&psn, windowID: windowID, mode: userGenerated)
        makeKeyWindow(&psn, windowID: windowID)
    }

    private static func isSameProcess(_ a: ProcessSerialNumber, _ b: ProcessSerialNumber) -> Bool {
        a.highLongOfPSN == b.highLongOfPSN && a.lowLongOfPSN == b.lowLongOfPSN
    }

    private static func put(_ value: UInt32, into bytes: inout [UInt8], at offset: Int) {
        withUnsafeBytes(of: value) { bytes.replaceSubrange(offset..<offset + 4, with: $0) }
    }
}
