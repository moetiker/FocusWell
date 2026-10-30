// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "FocusWell",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "FocusWell", targets: ["FocusWell"]),
    ],
    targets: [
        .target(name: "FocusWellCore"),
        // The menu bar app. `make app` puts it into FocusWell.app.
        .executableTarget(name: "FocusWell", dependencies: ["FocusWellCore"]),
        .testTarget(name: "FocusWellCoreTests", dependencies: ["FocusWellCore"]),
    ]
)
