// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Sleepless",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Sleepless",
            path: "Sources/Sleepless"
        )
    ]
)
