// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "everyDock",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "everyDock", targets: ["EveryDock"])],
    targets: [
        .target(name: "DockCore"),
        .executableTarget(name: "EveryDock", dependencies: ["DockCore"]),
        .testTarget(name: "DockCoreTests", dependencies: ["DockCore"])
    ]
)
