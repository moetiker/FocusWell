// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FocusWell",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FocusWell", targets: ["FocusWell"]),
    ],
    targets: [
        // Undocumented and deprecated system calls that Swift can not declare or
        // call directly. Everything that may break across macOS versions lives here.
        .target(name: "PrivateAPI"),
        .target(name: "FocusWellCore", dependencies: ["PrivateAPI"]),
        // The menu bar app. `make app` puts it into FocusWell.app.
        .executableTarget(name: "FocusWell", dependencies: ["FocusWellCore"]),
        .testTarget(name: "FocusWellCoreTests", dependencies: ["FocusWellCore"]),
    ]
)
