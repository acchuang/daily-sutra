// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DailySutra",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DailySutra",
            path: "Sources/DailySutra",
            resources: [.copy("Resources/verses.json")]
        )
    ]
)