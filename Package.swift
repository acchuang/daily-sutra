// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "DailySutra",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SutraKit", path: "Sources/SutraKit"),
        .executableTarget(
            name: "DailySutra",
            dependencies: ["SutraKit"],
            path: "Sources/DailySutra",
            resources: [
                .copy("Resources/verses.json"),
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/MenubarIcon.png"),
            ]
        ),
        .testTarget(
            name: "DailySutraTests",
            dependencies: ["SutraKit"],
            path: "Tests/DailySutraTests"
        ),
    ]
)