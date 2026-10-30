/// Apps and windows that need special treatment. Matching is on the English names.
enum Rules {
    static let mainWindowAppsWithoutTitle = [
        "System Settings",
        "System Information",
        "Photos",
        "Calculator",
        "Podcasts",
        "Stickies Pro",
        "Reeder",
        "PDFgear",
    ]
    static let pwaBrowsers = ["Chrome", "Chromium", "Vivaldi", "Brave", "Opera", "edgemac", "helium"]
    /// These raise their window when it gets the focus, so they only get it when
    /// the mouse moves to another app or out of the focused window.
    static let appsRaisingOnFocus = ["IntelliJ IDEA", "PyCharm", "WebStorm", "Arc", "Dia"]

    static let dockBundleId = "com.apple.dock"
    static let assistiveControl = "AssistiveControl"
    static let missionControl = "Mission Control"
    static let bartenderBar = "Bartender Bar"
    static let appStoreSearchResults = "Search results"
    static let untitled = "Untitled" // Mail search
    static let zim = "Zim"
    static let xQuartz = "XQuartz"
    static let finder = "Finder"
    static let noTitle = ""

    /// Progressive web apps installed from a Chromium based browser, or made with Pake.
    static func isPWA(_ bundleIdentifier: String?) -> Bool {
        guard let components = bundleIdentifier?.components(separatedBy: ".") else { return false }
        let pake = components.count == 3 && components[1] == "pake"
        // browser channels (canary, beta, dev) insert one component before "app"
        return pake || (components.count > 4 && pwaBrowsers.contains(components[2]) &&
            (components[3] == "app" || (components.count > 5 && components[4] == "app")))
    }
}
