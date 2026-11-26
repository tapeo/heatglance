// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeatGlanceKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "HeatGlanceCore", targets: ["HeatGlanceCore"]),
        .library(name: "HeatGlanceSystem", targets: ["HeatGlanceSystem"]),
    ],
    targets: [
        .target(
            name: "HeatGlanceCore",
            resources: [.process("Resources")]
        ),
        .target(name: "HeatGlanceSystem", dependencies: ["HeatGlanceCore"]),
        .testTarget(name: "HeatGlanceCoreTests", dependencies: ["HeatGlanceCore"]),
        .testTarget(name: "HeatGlanceSystemTests", dependencies: ["HeatGlanceSystem"]),
    ]
)
