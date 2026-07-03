// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexUsage",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "CodexUsageShared", targets: ["CodexUsageShared"]),
        .library(name: "CodexUsageNativeHostCore", targets: ["CodexUsageNativeHostCore"]),
        .executable(name: "CodexUsageMenubar", targets: ["CodexUsageMenubar"]),
        .executable(name: "CodexUsageNativeHost", targets: ["CodexUsageNativeHost"])
    ],
    targets: [
        .target(name: "CodexUsageShared"),
        .target(name: "CodexUsageNativeHostCore", dependencies: ["CodexUsageShared"]),
        .executableTarget(name: "CodexUsageMenubar", dependencies: ["CodexUsageShared"]),
        .executableTarget(name: "CodexUsageNativeHost", dependencies: ["CodexUsageNativeHostCore"]),
        .testTarget(name: "CodexUsageSharedTests", dependencies: ["CodexUsageShared"]),
        .testTarget(name: "CodexUsageNativeHostCoreTests", dependencies: ["CodexUsageNativeHostCore", "CodexUsageShared"])
    ]
)
