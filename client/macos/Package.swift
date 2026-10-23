// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SonicFlow",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SonicFlowCore"),
        .executableTarget(name: "SonicFlow", dependencies: ["SonicFlowCore"]),
        .testTarget(name: "SonicFlowCoreTests", dependencies: ["SonicFlowCore"]),
    ],
    swiftLanguageModes: [.v5]
)
