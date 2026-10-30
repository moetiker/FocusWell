import AppKit
import FocusWellCore

/// A balloon in the menu bar, green while the focus follows the mouse and red while
/// it does not. A click switches it on and off, the menu on a right click also quits.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let enabledKey = "enabled"

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let enabledItem = NSMenuItem()
    private let accessItem = NSMenuItem()
    private var engine: FocusEngine?
    private var trustTimer: Timer?

    private var enabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(enabled, forKey: Self.enabledKey)
            update()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        enabledItem.title = Text.active
        enabledItem.target = self
        enabledItem.action = #selector(toggle)
        accessItem.title = Text.allowAccess
        accessItem.target = self
        accessItem.action = #selector(requestAccess)
        menu.addItem(enabledItem)
        menu.addItem(accessItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: Text.quit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        // no statusItem.menu: it would open on every click
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        if !FocusEngine.isTrusted(prompt: true) { watchTrust() }
        update()
    }

    /// A click switches on and off, a right click or control click opens the menu.
    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else if !FocusEngine.isTrusted() {
            requestAccess()
        } else {
            toggle()
        }
    }

    @objc private func toggle() {
        enabled.toggle()
    }

    @objc private func requestAccess() {
        _ = FocusEngine.isTrusted(prompt: true)
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
        watchTrust()
    }

    /// macOS does not announce a granted permission, so poll until it is there.
    private func watchTrust() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { [weak self] in
                guard let self, FocusEngine.isTrusted() else { return }
                trustTimer?.invalidate()
                trustTimer = nil
                update()
            }
        }
    }

    /// Starts or stops the engine to match the state and colours the balloon.
    private func update() {
        let trusted = FocusEngine.isTrusted()
        let running = enabled && trusted && FocusEngine.isAvailable

        if running && engine == nil {
            var settings = Settings()
            settings.verbose = ProcessInfo.processInfo.environment["FOCUSWELL_VERBOSE"] != nil
            let engine = FocusEngine(settings: settings)
            engine.start()
            self.engine = engine
        } else if !running {
            engine?.stop()
            engine = nil
        }

        enabledItem.state = enabled ? .on : .off
        accessItem.isHidden = trusted
        if !FocusEngine.isAvailable {
            enabledItem.title = Text.unavailable
            enabledItem.isEnabled = false
        }

        let color: NSColor = running ? .systemGreen : .systemRed
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            .applying(.init(paletteColors: [color]))
        let image = NSImage(systemSymbolName: "balloon.fill", accessibilityDescription: "FocusWell")?
            .withSymbolConfiguration(config)
        image?.isTemplate = false
        statusItem.button?.image = image
        statusItem.button?.toolTip = running ? Text.tooltipActive : Text.tooltipInactive
    }
}

/// The menu in English, or in German when that is the first preferred language.
enum Text {
    static let german = Locale.preferredLanguages.first?.hasPrefix("de") ?? false

    static let active = german ? "Aktiv" : "Active"
    static let allowAccess = german ? "Bedienungshilfen erlauben…" : "Allow Accessibility Access…"
    static let quit = german ? "FocusWell beenden" : "Quit FocusWell"
    static let unavailable = german
        ? "Auf diesem macOS nicht verfügbar" : "Not available on this macOS"
    static let tooltipActive = german
        ? "FocusWell: Fokus folgt der Maus" : "FocusWell: focus follows the mouse"
    static let tooltipInactive = german ? "FocusWell: aus" : "FocusWell: off"
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
